## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

# Liquidity Protection Hook for Uniswap v4

A Uniswap v4 hook that provides liquidity protection mechanisms including impermanent loss protection and fee distribution for liquidity providers.

## Features

- **Impermanent Loss Protection**: Compensates liquidity providers for impermanent loss using a dedicated reserve pool
- **Fee Distribution System**: 
  - 80% to Liquidity Providers
  - 15% to IL Protection Reserve
  - 5% to Governance Token Holders
- **Price Feed Integration**: Uses Chainlink price feeds for accurate asset valuation
- **Flexible Hook Permissions**: Implements multiple hook points for comprehensive liquidity management

## Architecture

### Core Components

1. **LiquidityProtectionHook.sol**
   - Main hook contract implementing the protection mechanisms
   - Inherits from Uniswap v4's BaseHook
   - Manages fee distribution and IL protection

2. **MockPriceFeed.sol**
   - Test implementation of Chainlink's AggregatorV3Interface
   - Used for testing price feed functionality

3. **HookDeployer.sol**
   - Utility contract for deploying hooks with correct permission flags
   - Uses CREATE2 for deterministic address generation

### Hook Permissions

The hook implements the following permission flags:
- Before/After Add Liquidity
- Before/After Remove Liquidity
- Before/After Swap
- Delta Return capabilities for precise fee calculations

## Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/BTBLiquidityProtection.git
cd BTBLiquidityProtection

# Install dependencies
forge install
```

## Testing

```bash
# Run all tests
forge test --ffi

# Run specific test
forge test --match-test test_HookRegistration -vvv
```

## Development Setup

### Prerequisites

- [Foundry](https://github.com/foundry-rs/foundry)
- Solidity ^0.8.26
- Node.js (optional, for deployment scripts)

### Environment Setup

1. Install Foundry:
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

2. Build the project:
```bash
forge build
```

## Contract Deployment

1. Deploy to testnet:
```bash
forge script script/Deploy.s.sol:Deploy --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

2. Verify contract:
```bash
forge verify-contract $CONTRACT_ADDRESS src/hooks/LiquidityProtectionHook.sol:LiquidityProtectionHook
```

## Usage

### Setting Up Price Feeds

```solidity
// Set price feed for a pool
hook.setPriceFeed(poolKey, PRICE_FEED_ADDRESS);
```

### Managing Voter Shares

```solidity
// Update voter shares
hook.updateVoterShares(voterAddress, newShares);
```

### Claiming IL Protection

```solidity
// Claim IL protection for a position
hook.claimILProtection(poolKey, positionId);
```

## Security Considerations

1. **Price Feed Reliability**: 
   - Uses Chainlink price feeds for reliable price data
   - Implements fallback mechanisms for price feed failures

2. **Access Control**:
   - Owner-only functions for critical operations
   - Protected hook functions with proper modifiers

3. **Fee Distribution**:
   - Atomic operations for fee distribution
   - Protected against reentrancy attacks

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Uniswap v4 Team for the hook system architecture
- Chainlink for price feed infrastructure
- OpenZeppelin for secure contract implementations
