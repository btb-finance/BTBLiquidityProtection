# BTB Liquidity Protection V4 - Foundry Implementation

A Uniswap V4 hook implementation providing advanced liquidity protection mechanisms, featuring impermanent loss protection and enhanced fee distribution. Built with Foundry for Ethereum development.

## Features

**Core Protection Mechanisms:**
- Impermanent Loss Protection with reserve pool
- Dynamic Fee Distribution:
  - 80% to Liquidity Providers
  - 15% to IL Protection Reserve
  - 5% to Governance Token Holders
- Liquidity Provider Rewards System
- Position Management Utilities

**Advanced Functionality:**
- Chainlink Price Feed Integration
- Flexible Hook Permissions:
  - Before/After Add/Remove Liquidity
  - Before/After Swap
  - Delta Return capabilities
- CREATE2 Deployment Support

## Architecture

### Core Components
- **LiquidityProtectionHook.sol**  
  Main hook contract inheriting from Uniswap v4's BaseHook
- **BTBHook.sol**  
  Core implementation for position tracking and fee management
- **MockPriceFeed.sol**  
  Test implementation of Chainlink's AggregatorV3Interface
- **HookDeployer.sol**  
  CREATE2 utility for deterministic deployments

### System Integration
- Price Oracle: Chainlink with fallback mechanisms
- Fee Distribution: Atomic operations with reentrancy protection
- Access Control: Owner-restricted critical functions

## Development Setup

### Prerequisites
- Foundry
- Solidity ^0.8.26
- Node.js (for deployment scripts)

### Installation
```bash
# Clone repository
git clone https://github.com/btb-finance/BTBLiquidityProtection.git
cd BTBLiquidityProtection

# Install dependencies
forge install

# Build project
forge build
```

## Usage

### Testing
```bash
# Run all tests
forge test --ffi

# Run specific test with verbosity
forge test --match-test test_HookRegistration -vvv
```

### Deployment
```bash
# Deploy to network
forge script script/Deploy.s.sol:Deploy --rpc-url $RPC_URL --private-key $PRIVATE_KEY

# Verify contract
forge verify-contract $CONTRACT_ADDRESS src/hooks/LiquidityProtectionHook.sol:LiquidityProtectionHook
```

### Key Operations
```solidity
// Set price feed for pool
hook.setPriceFeed(poolKey, PRICE_FEED_ADDRESS);

// Update voter shares
hook.updateVoterShares(voterAddress, newShares);

// Claim IL protection
hook.claimILProtection(poolKey, positionId);
```

## Security

### Key Considerations
- **Price Reliability:** Chainlink feeds with fallback mechanisms
- **Access Controls:** Owner-restricted critical functions
- **Fee Safety:** Atomic distribution operations
- **Reentrancy Protection:** Secure modifiers on all hook functions

## Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature/new-feature`
3. Commit changes: `git commit -m 'Add new feature'`
4. Push to branch: `git push origin feature/new-feature`
5. Open Pull Request

## License
MIT - See [LICENSE](LICENSE) for details

## Acknowledgments
- Uniswap v4 Team for hook architecture
- Chainlink for oracle infrastructure
- OpenZeppelin for security patterns
- Paradigm for Foundry toolkit
