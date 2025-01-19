// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {BTBHook} from "../../src/hooks/BTBHook.sol";
import {IPoolManager} from "@uniswap/v4-core/contracts/interfaces/IPoolManager.sol";
import {Hooks} from "@uniswap/v4-core/contracts/libraries/Hooks.sol";

contract BTBHookTest is Test {
    BTBHook public hook;

    function setUp() public {
        // Deploy a mock pool manager
        address mockPoolManager = makeAddr("poolManager");
        hook = new BTBHook(IPoolManager(mockPoolManager));
    }

    function test_HooksCalls() public {
        Hooks.Calls memory hooks = hook.getHooksCalls();
        
        assertFalse(hooks.beforeInitialize);
        assertFalse(hooks.afterInitialize);
        assertFalse(hooks.beforeModifyPosition);
        assertFalse(hooks.afterModifyPosition);
        assertFalse(hooks.beforeSwap);
        assertFalse(hooks.afterSwap);
        assertFalse(hooks.beforeDonate);
        assertFalse(hooks.afterDonate);
    }
}
