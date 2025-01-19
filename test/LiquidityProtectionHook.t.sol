// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {GasSnapshot} from "forge-gas-snapshot/GasSnapshot.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {LiquidityProtectionHook} from "../src/hooks/LiquidityProtectionHook.sol";
import {MockBTB} from "../src/test/MockBTB.sol";
import {MockPriceFeed} from "../src/test/MockPriceFeed.sol";
import {HookDeployer} from "./utils/HookDeployer.sol";

contract LiquidityProtectionHookTest is Test, GasSnapshot {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    LiquidityProtectionHook public hook;
    PoolManager public poolManager;
    MockPriceFeed public priceFeed;
    
    address public constant OWNER = address(0x1);
    address public constant LP_USER = address(0x2);
    address public constant VOTER = address(0x3);
    address public constant PROTOCOL_OWNER = address(0x4);
    
    // Test values
    int256 constant TOKEN_PRICE = 1000e18; // $1000

    function setUp() public {
        // Deploy mock price feed
        priceFeed = new MockPriceFeed(TOKEN_PRICE, 18);
        
        // Deploy pool manager with protocol owner
        poolManager = new PoolManager(PROTOCOL_OWNER);
        
        // Deploy hook using the deployer
        vm.startPrank(OWNER);
        hook = HookDeployer.deploy(IPoolManager(address(poolManager)), OWNER);
        vm.stopPrank();
    }

    function test_HookRegistration() public {
        Hooks.Permissions memory permissions = hook.getHookPermissions();
        
        assertTrue(permissions.beforeAddLiquidity);
        assertTrue(permissions.afterAddLiquidity);
        assertTrue(permissions.beforeRemoveLiquidity);
        assertTrue(permissions.afterRemoveLiquidity);
        assertTrue(permissions.beforeSwap);
        assertTrue(permissions.afterSwap);
        assertTrue(permissions.beforeSwapReturnDelta);
        assertTrue(permissions.afterSwapReturnDelta);
        assertTrue(permissions.afterAddLiquidityReturnDelta);
        assertTrue(permissions.afterRemoveLiquidityReturnDelta);
        
        assertFalse(permissions.beforeInitialize);
        assertFalse(permissions.afterInitialize);
        assertFalse(permissions.beforeDonate);
        assertFalse(permissions.afterDonate);
    }

    function test_SetPriceFeed() public {
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(1)),
            currency1: Currency.wrap(address(2)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });

        vm.prank(OWNER);
        hook.setPriceFeed(key, address(priceFeed));

        assertEq(address(hook.priceFeedsForPools(key.toId())), address(priceFeed));
    }

    function test_UpdateVoterShares() public {
        uint256 shares = 1000e18;
        
        vm.prank(OWNER);
        hook.updateVoterShares(VOTER, shares);
        
        assertEq(hook.voterShares(VOTER), shares);
        assertEq(hook.totalVoterShares(), shares);
    }

    function test_FundILReserve() public {
        uint256 amount = 1000e18;
        
        hook.fundILReserve(amount);
        
        assertEq(hook.ilReserve(), amount);
    }
}
