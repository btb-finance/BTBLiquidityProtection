// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract ImpermanentLossProtectionHook is BaseHook, Ownable {
    using PoolIdLibrary for PoolKey;

    struct LiquidityInfo {
        uint256 initialUSDCValue;
        uint256 lastClaimedTimestamp;
        uint256 totalFeeEarned0;
        uint256 totalFeeEarned1;
    }

    mapping(address => mapping(PoolId => LiquidityInfo)) public userLiquidity;
    mapping(address => bool) public whitelistedTokens;

    // chainlink price feeds
    AggregatorV3Interface public priceFeedToken0;
    AggregatorV3Interface public priceFeedToken1;

    address public immutable treasury;
    address public immutable usdcToken;

    uint256 public constant PLATFORM_FEE_PERCENTAGE = 20; // 20% fee

    // ============================ CONSTRUCTOR ============================

    constructor(
        IPoolManager _poolManager,
        address _treasury,
        address _usdcToken,
        address _priceFeedToken0,
        address _priceFeedToken1
    ) BaseHook(_poolManager) {
        treasury = _treasury;
        usdcToken = _usdcToken;

        priceFeedToken0 = AggregatorV3Interface(_priceFeedToken0);
        priceFeedToken1 = AggregatorV3Interface(_priceFeedToken1);
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: true,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: true,
            afterRemoveLiquidity: true,
            beforeSwap: false,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    // ============================ LIQUIDITY MANAGEMENT ============================

    function beforeAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata
    ) external override returns (bytes4) {
        require(whitelistedTokens[address(key.currency0)] && whitelistedTokens[address(key.currency1)], "Token not whitelisted");

        // calculate initial value in usdc
        uint256 valueInUSDC = _calculateLPValueInUSDC(key, params.amount0, params.amount1);

        PoolId poolId = key.toId();
        userLiquidity[sender][poolId] = LiquidityInfo({
            initialUSDCValue: valueInUSDC,
            lastClaimedTimestamp: block.timestamp,
            totalFeeEarned0: 0,
            totalFeeEarned1: 0
        });

        return BaseHook.beforeAddLiquidity.selector;
    }

    function beforeRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata
    ) external override returns (bytes4) {
        PoolId poolId = key.toId();
        LiquidityInfo storage info = userLiquidity[sender][poolId];

        uint256 currentValueInUSDC = _calculateLPValueInUSDC(key, params.amount0, params.amount1);

        // if lp is worth less than initial value, refund difference from treasury
        if (currentValueInUSDC < info.initialUSDCValue) {
            uint256 refundAmount = info.initialUSDCValue - currentValueInUSDC;
            IERC20(usdcToken).transferFrom(treasury, sender, refundAmount);
        }

        return BaseHook.beforeRemoveLiquidity.selector;
    }

    function afterRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata,
        BalanceDelta delta,
        bytes calldata
    ) external override returns (bytes4, BalanceDelta) {
        PoolId poolId = key.toId();
        delete userLiquidity[sender][poolId];
        return (BaseHook.afterRemoveLiquidity.selector, delta);
    }

    // ============================ FEE CLAIMING ============================

    /**
     * @notice allows users to claim fees anytime
     * @dev 20% fee goes to treasury, 80% goes to the user
     */
    function claimFees(PoolKey calldata key) external {
        PoolId poolId = key.toId();
        LiquidityInfo storage info = userLiquidity[msg.sender][poolId];
        require(info.lastClaimedTimestamp > 0, "No liquidity provided");

        // calculate fees earned since last claim
        uint256 feeEarned0 = info.totalFeeEarned0;
        uint256 feeEarned1 = info.totalFeeEarned1;

        require(feeEarned0 > 0 || feeEarned1 > 0, "No fees to claim");

        // reset fee counters
        info.totalFeeEarned0 = 0;
        info.totalFeeEarned1 = 0;
        info.lastClaimedTimestamp = block.timestamp;

        // 20% fee to treasury, 80% to user
        uint256 fee0Platform = (feeEarned0 * PLATFORM_FEE_PERCENTAGE) / 100;
        uint256 fee1Platform = (feeEarned1 * PLATFORM_FEE_PERCENTAGE) / 100;

        uint256 fee0User = feeEarned0 - fee0Platform;
        uint256 fee1User = feeEarned1 - fee1Platform;

        // transfer fees
        if (fee0User > 0) IERC20(address(key.currency0)).transfer(msg.sender, fee0User);
        if (fee1User > 0) IERC20(address(key.currency1)).transfer(msg.sender, fee1User);

        if (fee0Platform > 0) IERC20(address(key.currency0)).transfer(treasury, fee0Platform);
        if (fee1Platform > 0) IERC20(address(key.currency1)).transfer(treasury, fee1Platform);
    }

    // ============================ PRICE CALCULATION ============================

    /**
     * @notice calculates LP value in USDC using the chainlink price feeds
     */
    function _calculateLPValueInUSDC(PoolKey calldata key, uint256 amount0, uint256 amount1) internal view returns (uint256) {
        uint256 price0 = getLatestPrice(priceFeedToken0);
        uint256 price1 = getLatestPrice(priceFeedToken1);

        return (amount0 * price0) / 1e8 + (amount1 * price1) / 1e8; // chainlink prices have 8 decimal places
    }

    /**
     * @notice get the latest price from chainlink
     */
    function getLatestPrice(AggregatorV3Interface priceFeed) internal view returns (uint256) {
        (
            , 
            int256 price, 
            , 
            , 
        ) = priceFeed.latestRoundData();

        require(price > 0, "Invalid price");

        return uint256(price);
    }

    // ============================ TOKEN WHITELIST ============================

    function addWhitelistedToken(address token) external onlyOwner {
        whitelistedTokens[token] = true;
    }

    function removeWhitelistedToken(address token) external onlyOwner {
        whitelistedTokens[token] = false;
    }

    // ============================ ADMIN FUNCTIONS ============================

    function setPriceFeeds(address _token0Feed, address _token1Feed) external onlyOwner {
        priceFeedToken0 = AggregatorV3Interface(_token0Feed);
        priceFeedToken1 = AggregatorV3Interface(_token1Feed);
    }
}
