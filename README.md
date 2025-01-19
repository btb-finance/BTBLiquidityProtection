# BTB Liquidity Protection V4

A Uniswap V4 hook implementation for BTB Liquidity Protection, designed to protect liquidity providers from impermanent loss and enhance their trading experience.

## Overview

This project implements Uniswap V4 hooks to provide advanced liquidity protection features:

- Impermanent Loss Protection
- Dynamic Fee Adjustment
- Liquidity Provider Rewards
- Position Management

## Architecture

The project consists of several key components:

- `BTBHook.sol`: Core hook implementation for Uniswap V4 integration
- Position tracking and management
- Fee collection and distribution
- Price oracle integration

## Development

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation.html)
- Solidity ^0.8.24

### Setup

1. Clone the repository:
```bash
git clone https://github.com/btb-finance/BTBLiquidityProtection.git
cd BTBLiquidityProtection
```

2. Install dependencies:
```bash
forge install
```

3. Build the project:
```bash
forge build
```

4. Run tests:
```bash
forge test
```

### Testing

The project includes comprehensive tests:
- Unit tests for hook functionality
- Integration tests with Uniswap V4
- Mock contracts for testing

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT
