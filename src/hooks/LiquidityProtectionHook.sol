// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "@uniswap/v4-periphery/src/base/hooks/BaseHook.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Pool} from "@uniswap/v4-core/src/libraries/Pool.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LiquidityProtectionHook is BaseHook, Ownable {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    // Mapping for voter shares (for governance on refund eligibility)
    mapping(address => uint256) public voterShares;
    uint256 public totalVoterShares;

    // IL (Impermanent Loss) reserve funded by external sources
    uint256 public ilReserve;

    // Mapping to store each liquidity provider’s initial USD investment.
    // (For simplicity, this example assumes one position per user.)
    mapping(address => uint256) public initialInvestment;

    // BTB token address used for compensating LPs if they experience a loss.
    address public btbToken;

    // BTB token price in USD, scaled to 18 decimals.
    // For example, if 1 BTB token = $1, then btbTokenPrice should be set to 1e18.
    uint256 public btbTokenPrice;

    // Events
    event VoterSharesUpdated(address indexed voter, uint256 shares);
    event ILReserveFunded(uint256 amount);
    event ILCompensationPaid(address indexed user, uint256 amount);
    event BTBTokenUpdated(address newBTBToken);
    event BTBTokenPriceUpdated(uint256 newPrice);

    constructor(IPoolManager _poolManager, address initialOwner) BaseHook(_poolManager) Ownable(initialOwner) {}

    // Allows the owner to set (or update) the BTB token address.
    function setBTBToken(address _btbToken) external onlyOwner {
        require(_btbToken != address(0), "LiquidityProtectionHook: BTB token cannot be zero address");
        btbToken = _btbToken;
        emit BTBTokenUpdated(_btbToken);
    }

    // Allows the owner to set (or update) the BTB token price in USD (scaled to 18 decimals).
    function setBTBTokenPrice(uint256 newPrice) external onlyOwner {
        require(newPrice > 0, "LiquidityProtectionHook: BTB token price must be greater than zero");
        btbTokenPrice = newPrice;
        emit BTBTokenPriceUpdated(newPrice);
    }

    // Returns hook permissions for all callback phases.
    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: true,
            afterAddLiquidity: true,
            beforeRemoveLiquidity: true,
            afterRemoveLiquidity: true,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: true,
            afterSwapReturnDelta: true,
            afterAddLiquidityReturnDelta: true,
            afterRemoveLiquidityReturnDelta: true
        });
    }

    // Owner-only function to update voter shares.
    function updateVoterShares(address voter, uint256 shares) external onlyOwner {
        require(voter != address(0), "LiquidityProtectionHook: voter cannot be zero address");
        uint256 oldShares = voterShares[voter];
        voterShares[voter] = shares;
        totalVoterShares = totalVoterShares - oldShares + shares;
        emit VoterSharesUpdated(voter, shares);
    }

    // Anyone can call this function to fund the IL reserve.
    function fundILReserve(uint256 amount) external {
        ilReserve += amount;
        emit ILReserveFunded(amount);
    }

    // Admin functions to allow the owner to claim any ERC20 tokens held by the contract.
    function claimToken(address token, uint256 amount) external onlyOwner {
        require(IERC20(token).balanceOf(address(this)) >= amount, "LiquidityProtectionHook: insufficient token balance");
        IERC20(token).transfer(owner(), amount);
    }

    // Admin function to claim ETH held by the contract.
    function claimETH(uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "LiquidityProtectionHook: insufficient ETH balance");
        payable(owner()).transfer(amount);
    }

    // Allow the contract to receive ETH.
    receive() external payable {}

    // -------------------------------------
    // Hook Callback Functions
    // -------------------------------------

    // Called before adding liquidity (pass-through).
    function beforeAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external override returns (bytes4) {
        return BaseHook.beforeAddLiquidity.selector;
    }

    // Called after liquidity is added.
    // This function calculates the USD value of the liquidity added and stores it as the sender’s initial investment.
    // (It assumes that params.amount0 and params.amount1 represent the amounts added.)
    function afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta hookDelta,
        bytes calldata hookData
    ) external override returns (bytes4, BalanceDelta) {
        uint256 usdValue = calculateUsdValue(key, params.liquidityDelta > 0 ? uint256(params.liquidityDelta) : uint256(-params.liquidityDelta), 0); 
        // Record the initial investment or accumulate additional deposits.
        if (initialInvestment[sender] == 0) {
            initialInvestment[sender] = usdValue;
        } else {
            initialInvestment[sender] += usdValue;
        }
        return (BaseHook.afterAddLiquidity.selector, BalanceDelta.wrap(0));
    }

    // Called before removing liquidity (pass-through).
    function beforeRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external override returns (bytes4) {
        return BaseHook.beforeRemoveLiquidity.selector;
    }

    // Called after liquidity is removed.
    // This function calculates the current USD value of the removed liquidity and compares it to the stored initial investment.
    // If the current value is less (i.e. the LP is at a loss), it refunds the difference in BTB tokens.
    // The USD loss is converted into BTB tokens using the set BTB token price.
    function afterRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta hookDelta,
        bytes calldata hookData
    ) external override returns (bytes4, BalanceDelta) {
        uint256 currentValue = calculateUsdValue(key, params.liquidityDelta > 0 ? uint256(params.liquidityDelta) : uint256(-params.liquidityDelta), 0); 
        uint256 initialVal = initialInvestment[sender];
        if (initialVal > 0 && currentValue < initialVal) {
            uint256 loss = initialVal - currentValue;
            require(btbToken != address(0), "LiquidityProtectionHook: BTB token not set");
            require(btbTokenPrice > 0, "LiquidityProtectionHook: BTB token price not set");
            // Convert the USD loss into the BTB token amount.
            // Formula: tokenAmount = (loss * 1e18) / btbTokenPrice
            uint256 tokenAmount = (loss * 1e18) / btbTokenPrice;
            uint256 btbBalance = IERC20(btbToken).balanceOf(address(this));
            if (btbBalance >= tokenAmount) {
                IERC20(btbToken).transfer(sender, tokenAmount);
                emit ILCompensationPaid(sender, tokenAmount);
            }
        }
        // Clear the recorded investment for the sender.
        initialInvestment[sender] = 0;
        return (BaseHook.afterRemoveLiquidity.selector, BalanceDelta.wrap(0));
    }

    // Called before a swap (pass-through).
    function beforeSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata hookData
    ) external override returns (bytes4, BeforeSwapDelta, uint24) {
        return (BaseHook.beforeSwap.selector, BeforeSwapDelta.wrap(0), 0);
    }

    // Called after a swap.
    // The fee calculation and splitting logic has been removed so that liquidity providers can choose any fee externally.
    function afterSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external override returns (bytes4, int128) {
        return (BaseHook.afterSwap.selector, 0);
    }

    // -------------------------------------
    // Internal Helper Functions
    // -------------------------------------

    /// @notice Calculates the USD value of a liquidity position using Uniswap V4's price mechanism.
    /// @dev Retrieves the pool’s slot0 from poolManager to get sqrtPriceX96, squares it, and shifts right by 192 bits.
    ///      Assumes both tokens have 18 decimals.
    function calculateUsdValue(
        PoolKey calldata key,
        uint256 amount0,
        uint256 amount1
    ) public view returns (uint256) {
        // For now, we'll use a simplified price calculation using the BTB token price
        uint256 value = (amount0 * btbTokenPrice) / 1e18;
        return value;
    }
}
