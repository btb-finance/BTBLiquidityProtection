// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {HookDeployer} from "./utils/HookDeployer.sol";
import {LiquidityProtectionHook} from "../src/hooks/LiquidityProtectionHook.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

contract LiquidityProtectionHookTest is Test {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    LiquidityProtectionHook public hook;
    IPoolManager public poolManager;
    MockERC20 public btbToken;
    MockERC20 public token0;
    MockERC20 public token1;
    address public owner;
    address public user;

    function setUp() public {
        // Deploy mock tokens
        btbToken = new MockERC20("BTB Token", "BTB", 18);
        token0 = new MockERC20("Token0", "TK0", 18);
        token1 = new MockERC20("Token1", "TK1", 18);

        // Set up addresses
        owner = address(this);
        user = address(0x123);

        // Deploy pool manager (mock for testing)
        poolManager = IPoolManager(address(0x456)); // In real tests, deploy actual pool manager

        // Deploy hook with proper flags
        uint160 flags = uint160(
            Hooks.BEFORE_ADD_LIQUIDITY_FLAG | 
            Hooks.AFTER_ADD_LIQUIDITY_FLAG |
            Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG |
            Hooks.AFTER_REMOVE_LIQUIDITY_FLAG
        );
        
        // Deploy the hook
        hook = LiquidityProtectionHook(HookDeployer.deploy(poolManager, address(uint160(flags))));

        // Set up BTB token and price
        hook.setBTBToken(address(btbToken));
        hook.setBTBTokenPrice(1e18); // Set price to $1

        // Fund the hook with BTB tokens for refunds
        btbToken.mint(address(hook), 1000e18);

        // Set up user with tokens
        token0.mint(user, 1000e18);
        token1.mint(user, 1000e18);
        vm.deal(user, 100 ether);
    }

    function test_SetBTBToken() public {
        address newToken = address(0x789);
        hook.setBTBToken(newToken);
        assertEq(hook.btbToken(), newToken);
    }

    function test_SetBTBTokenPrice() public {
        uint256 newPrice = 2e18;
        hook.setBTBTokenPrice(newPrice);
        assertEq(hook.btbTokenPrice(), newPrice);
    }

    function test_OnlyOwnerCanSetBTBToken() public {
        vm.prank(user);
        vm.expectRevert("Ownable: caller is not the owner");
        hook.setBTBToken(address(0x789));
    }

    function test_OnlyOwnerCanSetBTBTokenPrice() public {
        vm.prank(user);
        vm.expectRevert("Ownable: caller is not the owner");
        hook.setBTBTokenPrice(2e18);
    }

    function test_CalculateUsdValue() public {
        uint256 amount = 100e18;
        uint256 expectedValue = amount; // Since price is 1e18, value should equal amount
        
        // Create a pool key for testing
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(token0)),
            currency1: Currency.wrap(address(token1)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });
        
        assertEq(hook.calculateUsdValue(key, amount, 0), expectedValue);
    }

    function test_AddLiquidity() public {
        // Create a pool key for testing
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(token0)),
            currency1: Currency.wrap(address(token1)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });

        // Simulate adding liquidity
        IPoolManager.ModifyLiquidityParams memory params = IPoolManager.ModifyLiquidityParams({
            tickLower: -100,
            tickUpper: 100,
            liquidityDelta: 1000e18,
            salt: bytes32(0)
        });

        vm.prank(user);
        (bytes4 selector,) = hook.afterAddLiquidity(
            user,
            key,
            params,
            BalanceDelta.wrap(0),
            BalanceDelta.wrap(0),
            ""
        );
        assertEq(selector, LiquidityProtectionHook.afterAddLiquidity.selector);
        assertEq(hook.initialInvestment(user), 1000e18);
    }

    function test_RemoveLiquidity() public {
        // Create a pool key for testing
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(token0)),
            currency1: Currency.wrap(address(token1)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });

        // First add liquidity
        IPoolManager.ModifyLiquidityParams memory addParams = IPoolManager.ModifyLiquidityParams({
            tickLower: -100,
            tickUpper: 100,
            liquidityDelta: 1000e18,
            salt: bytes32(0)
        });

        vm.prank(user);
        hook.afterAddLiquidity(
            user,
            key,
            addParams,
            BalanceDelta.wrap(0),
            BalanceDelta.wrap(0),
            ""
        );

        // Now remove liquidity at a loss
        IPoolManager.ModifyLiquidityParams memory removeParams = IPoolManager.ModifyLiquidityParams({
            tickLower: -100,
            tickUpper: 100,
            liquidityDelta: -800e18, // Remove less than initial to simulate loss
            salt: bytes32(0)
        });

        uint256 initialBTBBalance = btbToken.balanceOf(user);
        
        vm.prank(user);
        (bytes4 selector,) = hook.afterRemoveLiquidity(
            user,
            key,
            removeParams,
            BalanceDelta.wrap(0),
            BalanceDelta.wrap(0),
            ""
        );
        
        assertEq(selector, LiquidityProtectionHook.afterRemoveLiquidity.selector);
        assertTrue(btbToken.balanceOf(user) > initialBTBBalance); // User should receive BTB tokens as compensation
    }
}
