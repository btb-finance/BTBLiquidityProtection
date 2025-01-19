// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {LiquidityProtectionHook} from "../../src/hooks/LiquidityProtectionHook.sol";
import {BaseHook} from "@uniswap/v4-periphery/src/base/hooks/BaseHook.sol";

library HookDeployer {
    function deploy(IPoolManager poolManager, address owner) internal returns (LiquidityProtectionHook) {
        // Deploy to address with correct flags
        uint160 flags = uint160(
            Hooks.BEFORE_ADD_LIQUIDITY_FLAG |
            Hooks.AFTER_ADD_LIQUIDITY_FLAG |
            Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG |
            Hooks.AFTER_REMOVE_LIQUIDITY_FLAG |
            Hooks.BEFORE_SWAP_FLAG |
            Hooks.AFTER_SWAP_FLAG |
            Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG |
            Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG |
            Hooks.AFTER_ADD_LIQUIDITY_RETURNS_DELTA_FLAG |
            Hooks.AFTER_REMOVE_LIQUIDITY_RETURNS_DELTA_FLAG
        );

        // Calculate the target address for the implementation
        bytes memory creationCode = type(LiquidityProtectionHook).creationCode;
        bytes memory constructorArgs = abi.encode(poolManager);
        bytes memory bytecode = abi.encodePacked(creationCode, constructorArgs);

        // Try different salts until we find one that gives us the correct address
        bytes32 salt;
        address deployedAddress;
        uint256 nonce;
        address deployer;
        assembly {
            deployer := caller()
        }
        while (true) {
            salt = keccak256(abi.encodePacked(owner, nonce));
            address predictedAddress = computeAddress(salt, bytecode, deployer);
            if (uint160(predictedAddress) & uint160(0xFFFF) == flags) {
                // Deploy the contract
                assembly {
                    deployedAddress := create2(0, add(bytecode, 32), mload(bytecode), salt)
                    if iszero(extcodesize(deployedAddress)) { revert(0, 0) }
                }
                break;
            }
            nonce++;
        }

        // Verify deployment
        require(deployedAddress != address(0), "Failed to deploy hook");
        require(uint160(deployedAddress) & uint160(0xFFFF) == flags, "Hook flags not set correctly");

        // Return the hook with the correct flags
        return LiquidityProtectionHook(deployedAddress);
    }

    function computeAddress(bytes32 salt, bytes memory bytecode, address deployer) internal pure returns (address) {
        bytes32 hash = keccak256(
            abi.encodePacked(bytes1(0xff), deployer, salt, keccak256(bytecode))
        );
        return address(uint160(uint256(hash)));
    }
}
