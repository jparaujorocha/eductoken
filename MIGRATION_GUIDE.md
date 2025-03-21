# EducToken Migration Guide

This document outlines the process for migrating from the current EducToken implementation to the enhanced version with vesting, proxy upgradeability, and emergency recovery functionality.

## Overview of Enhancements

The migration includes the following enhancements:

1. **Token Upgradeability**: Implementation of UUPS proxy pattern for future upgrades
2. **Vesting Mechanism**: Comprehensive token vesting for initial distribution
3. **Emergency Recovery**: System for recovering tokens in emergency situations
4. **Enhanced Security**: Additional safety mechanisms and recovery options

## Pre-Migration Checklist

- [ ] Backup of all contract addresses and states
- [ ] Snapshot of all token holder balances
- [ ] Approval from governance for migration
- [ ] Testing of all new contracts on testnet
- [ ] Audit of new contract code

## Migration Steps

### 1. Deploy New Contracts

```bash
# Set environment variables
export EXISTING_TOKEN_ADDRESS=0x...
export TREASURY_ADDRESS=0x...

# Deploy upgradeable token
npx hardhat run scripts/deploy-upgradeable.js --network mainnet

# Deploy recovery system
npx hardhat run scripts/migrate-to-recovery.js --network mainnet

# Deploy vesting system
npx hardhat run scripts/deploy-vesting.js --network mainnet
```

### 2. Take Token Holder Snapshot

```bash
# Generate snapshot of current token holders
npx hardhat run scripts/create-token-snapshot.js --network mainnet

# Verify snapshot data
npx hardhat run scripts/verify-snapshot.js --network mainnet
```

### 3. Create Governance Proposal for Migration

Create a governance proposal with the following actions:
- Pause the old token contract
- Approve migration to new contracts
- Define vesting schedules for token distribution
- Set up emergency recovery parameters

### 4. Execute Migration

```bash
# Execute migration after proposal approval
npx hardhat run scripts/execute-migration.js --network mainnet
```

### 5. Verify Migration

```bash
# Verify balances after migration
npx hardhat run scripts/verify-migration.js --network mainnet

# Verify contract verification on Etherscan
npx hardhat run scripts/verify-proxy.js --network mainnet
```

## Post-Migration Tasks

1. **Update Documentation**: Update all documentation to reference new contract addresses
2. **Inform Token Holders**: Notify all token holders about the migration
3. **Update DApp Integration**: Update any DApps or frontends to interact with new contracts
4. **Monitor System**: Closely monitor the system for any issues

## Vesting Schedule Setup

The migration includes setting up the following vesting schedules:

1. **Team Allocation**: 1,000,000 tokens with 2-year linear vesting and 6-month cliff
2. **Advisors**: 500,000 tokens with 2-year linear vesting and 6-month cliff
3. **Strategic Partners**: 1,500,000 tokens with milestone-based vesting

For each vesting schedule:

```javascript
// Example vesting setup - this will be part of the migration script
const teamVestingTx = await vesting.createHybridVesting(
  teamAddress, 
  ethers.parseEther("1000000"), 
  startTime, 
  twoYearsInSeconds, 
  sixMonthsInSeconds, 
  true, 
  ethers.id("TEAM_ALLOCATION")
);
```

## Emergency Recovery System

The emergency recovery system includes:

1. **Emergency Levels**:
   - Level 1: Minor issue (monitoring)
   - Level 2: Moderate issue (restrictions)
   - Level 3: Critical issue (emergency mode)

2. **Recovery Process**:
   - Declaration of emergency with appropriate level
   - Multisig approval of emergency action
   - Execution of recovery operations
   - Resolution of emergency

```javascript
// Example emergency recovery - only for actual emergencies
const declareEmergencyTx = await emergencyRecovery.declareEmergency(
  2, // Level 2 emergency
  "Vulnerability detected in token transfer function"
);
```

## Contract Upgradeability

For future upgrades, use the following process:

```bash
# Set the proxy address
export PROXY_ADDRESS=0x...

# Deploy and upgrade implementation
npx hardhat run scripts/upgrade-token.js --network mainnet

# Verify new implementation
npx hardhat run scripts/verify-proxy.js --network mainnet
```

## Troubleshooting

### Common Issues

1. **Proxy Initialization Failure**:
   - Ensure initialization function is called only once
   - Verify correct admin address is provided

2. **Vesting Schedule Issues**:
   - Check that token allowance is sufficient for vesting contract
   - Verify correct beneficiary addresses

3. **Emergency Recovery Activation Failure**:
   - Ensure caller has emergency role
   - Verify multisig thresholds are correctly set

### Reverting to Previous State

In case of critical issues, follow these steps to revert:

1. Pause all new contracts
2. Notify all token holders
3. Deploy reversion contracts
4. Execute reversion transaction to restore previous state

## Support

For any issues during or after migration, contact:
- Technical Support