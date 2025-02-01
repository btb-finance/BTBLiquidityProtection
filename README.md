# BTB Liquidity Protection Hook

A Uniswap V4 hook designed to protect liquidity providers from impermanent loss by providing compensation in BTB tokens.

## Overview

The BTB Liquidity Protection Hook is a sophisticated smart contract that integrates with Uniswap V4 pools to provide protection against impermanent loss for liquidity providers. When LPs experience a loss upon removing their liquidity, they receive compensation in BTB tokens based on the USD value of their loss.

## Features

### Liquidity Protection
- Tracks initial USD value of liquidity provided
- Calculates losses when liquidity is removed
- Automatically compensates LPs with BTB tokens for their losses
- Supports multiple positions per user

### Governance
- Owner-controlled BTB token address and price settings
- Voter share system for potential governance decisions
- Impermanent Loss (IL) reserve for future enhancements

### Administrative Functions
- Owner can update BTB token address and price
- Owner can manage voter shares
- Emergency functions to recover tokens or ETH
- IL reserve funding mechanism

## Key Components

### BTB Token Integration
- BTB tokens are used as the compensation currency
- Token price is maintained in USD (18 decimal precision)
- Example: If 1 BTB = $1, then `btbTokenPrice = 1e18`

### Investment Tracking
- Records initial USD value when liquidity is added
- Compares final value when liquidity is removed
- Calculates loss and provides appropriate compensation

### Hook Callbacks
1. `beforeAddLiquidity`: Pass-through callback
2. `afterAddLiquidity`: Records initial investment value
3. `beforeRemoveLiquidity`: Pass-through callback
4. `afterRemoveLiquidity`: Calculates loss and provides compensation
5. `beforeSwap` & `afterSwap`: Pass-through callbacks

## Usage

### For Liquidity Providers
1. Add liquidity to a Uniswap V4 pool using this hook
2. Your initial investment value is automatically recorded
3. When removing liquidity:
   - If value has decreased: Receive BTB tokens as compensation
   - If value has increased or stayed same: No compensation needed

### For Administrators
1. Set BTB token address:
```solidity
hook.setBTBToken(address _btbToken)
```

2. Update BTB token price:
```solidity
hook.setBTBTokenPrice(uint256 newPrice)
```

3. Manage voter shares:
```solidity
hook.updateVoterShares(address voter, uint256 shares)
```

4. Fund IL reserve:
```solidity
hook.fundILReserve(uint256 amount)
```

## Security Features
- All admin functions are protected by OpenZeppelin's `Ownable`
- Zero-address checks for critical parameters
- Balance checks before token transfers
- ETH receiving capability for future enhancements

## Events
- `VoterSharesUpdated`: Emitted when voter shares are modified
- `ILReserveFunded`: Emitted when IL reserve receives funding
- `ILCompensationPaid`: Emitted when compensation is paid to an LP
- `BTBTokenUpdated`: Emitted when BTB token address is updated
- `BTBTokenPriceUpdated`: Emitted when BTB token price is updated

## Dependencies
- OpenZeppelin Contracts v5.2.0
- Uniswap V4 Core
- Uniswap V4 Periphery

## Development

### Prerequisites
- Foundry
- Node.js
- Git

### Installation
```bash
git clone https://github.com/your-repo/BTBLiquidityProtection
cd BTBLiquidityProtection
forge install
```

### Testing
```bash
forge test
```

## License
MIT
