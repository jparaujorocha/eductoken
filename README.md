# EducToken: Educational Incentives Token System

EducToken is a comprehensive ERC20 token ecosystem designed for decentralized educational incentives, enabling educators to issue tokens as rewards for students who complete courses, participate in activities, or achieve specific educational milestones.

## Project Overview

This project implements a complete token-based educational reward system on Ethereum with role-based access control, course management, student tracking, activity monitoring, governance features, token vesting, and emergency recovery mechanisms.

## Key Features

- **ERC20 Token Implementation**
  - Total Supply: 10,000,000 EDUC with 18 decimals
  - Controlled minting for educational rewards
  - Burning mechanism for expired/inactive tokens after 12 months
  - Daily minting limit of 1,000 tokens

- **Educational Reward System**
  - Specialized `mintReward` function with reason tracking
  - `batchMintReward` for efficient multiple student rewards
  - Comprehensive event logging with `RewardIssued` events
  - Inactive account detection and token recovery

- **Role-Based Access Control**
  - Admin role for system management
  - Educator role for course creation and rewards
  - Governance through multisignature proposals

- **Student Activity Tracking**
  - Detailed activity history by category
  - Timestamps for all student actions
  - Inactivity detection for account management

- **Course Management**
  - Create and update courses
  - Set reward amounts per course
  - Track course completions

- **Security Features**
  - Pausable operations with granular control
  - Comprehensive input validation
  - Protection against reentrancy attacks

- **Token Vesting**
  - Multiple vesting models (linear, cliff, hybrid, milestone-based)
  - Revocable and non-revocable schedules
  - Factory pattern for multiple vesting contracts
  - Detailed tracking and event logging

- **Proxy Upgradeability**
  - UUPS proxy pattern for future upgrades
  - Seamless contract updates without migration
  - Immutable storage layout for safe upgrades

- **Emergency Recovery**
  - Multi-level emergency response system
  - Token recovery mechanisms for stuck funds
  - Governance-controlled emergency actions
  - Circuit breakers for critical vulnerabilities

## System Architecture

### Core Contracts

- **EducToken**: Enhanced ERC20 token with education-specific reward functions
- **EducEducator**: Manages educator registrations and permissions
- **EducStudent**: Tracks student registrations, activities, and course completions
- **EducCourse**: Handles course creation and management
- **EducLearning**: Main integration contract with advanced reward functions

### Supporting Contracts

- **EducConfig**: System configuration parameters
- **EducPause**: Emergency pause functionality
- **EducMultisig**: Multisignature governance mechanism
- **EducProposal**: Proposal creation and execution for governance

### Advanced Features

- **EducTokenUpgradeable**: Upgradeable version of the token using UUPS proxy pattern
- **EducTokenWithRecovery**: Enhanced token with emergency recovery capabilities
- **EducVesting**: Token vesting contract for initial distribution
- **EducVestingFactory**: Factory for deploying multiple vesting contracts
- **EducEmergencyRecovery**: Emergency response system for critical issues

## Technical Specifications

- **Blockchain**: Ethereum
- **Language**: Solidity ^0.8.19
- **Framework**: Hardhat
- **Libraries**: OpenZeppelin Contracts 5.2.0, OpenZeppelin Contracts Upgradeable 5.2.0
- **Testing**: Mocha, Chai

## Development Environment Setup

### Prerequisites

- Node.js (v16+)
- npm or yarn
- Git

### Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/eductoken.git
cd eductoken
```

2. Install dependencies:
```bash
npm install
# or
yarn install
```

3. Create environment file:
```bash
cp .env.example .env
```

4. Fill in your environment variables in the `.env` file:
- Add your Ethereum node provider URLs
- Add your deployment wallet's private key
- Add API keys for verification

### Compilation

Compile the contracts:
```bash
npm run compile
# or
yarn compile
```

### Deployment

1. Start a local node for development:
```bash
npm run node
# or
yarn node
```

2. Deploy to local development network:
```bash
npm run deploy:local
# or
yarn deploy:local
```

3. Deploy to Sepolia testnet:
```bash
npm run deploy:sepolia
# or
yarn deploy:sepolia
```

### Deploying Advanced Features

#### Upgradeable Token System

Deploy the upgradeable token system:
```bash
npm run deploy:upgradeable
# or
npx hardhat run scripts/deploy-upgradeable.js --network <network-name>
```

#### Vesting System

Deploy the vesting system:
```bash
npm run deploy:vesting
# or
npx hardhat run scripts/deploy-vesting.js --network <network-name>
```

#### Emergency Recovery System

Deploy or migrate to the emergency recovery system:
```bash
npm run migrate:recovery
# or
npx hardhat run scripts/migrate-to-recovery.js --network <network-name>
```

### Token Snapshot

Create a snapshot of current token holders:
```bash
# Set the token address
export EXISTING_TOKEN_ADDRESS=0x...

# Create snapshot
npx hardhat run scripts/create-token-snapshot.js --network <network-name>
```

### Verifying Contracts

Verify the deployed contracts on Etherscan:
```bash
# For standard contracts
npm run verify -- --network <network-name> --contract <contract-path:ContractName> <deployed-address> <constructor-args>

# For proxy contracts
export PROXY_ADDRESS=0x...
npx hardhat run scripts/verify-proxy.js --network <network-name>
```

## Usage Examples

### Register an Educator

```javascript
const tx = await educatorContract.registerEducator(
  educatorAddress,
  ethers.utils.parseEther("1000") // Mint limit of 1000 tokens
);
await tx.wait();
```

### Issue Educational Rewards

```javascript
// Single reward
const tx = await educLearningContract.issueReward(
  studentAddress,
  ethers.utils.parseEther("10"),
  "Outstanding project submission"
);
await tx.wait();

// Batch rewards
const tx = await educLearningContract.batchIssueRewards(
  [student1, student2, student3],
  [
    ethers.utils.parseEther("5"),
    ethers.utils.parseEther("7"),
    ethers.utils.parseEther("3")
  ],
  ["Quiz completion", "Group project", "Active participation"]
);
await tx.wait();
```

### Complete a Course for a Student

```javascript
const tx = await educLearningContract.completeCourse(
  studentAddress,
  "CS101" // Course ID
);
await tx.wait();
```

### Burn Tokens from Inactive Accounts

```javascript
const tx = await educLearningContract.burnInactiveTokens(
  inactiveStudentAddress,
  ethers.utils.parseEther("50") // Amount to burn
);
await tx.wait();
```

### Set Up a Vesting Schedule

```javascript
// Create a linear vesting schedule
const startTime = Math.floor(Date.now() / 1000); // Start now
const oneYearInSeconds = 365 * 24 * 60 * 60;

const tx = await vestingContract.createLinearVesting(
  beneficiaryAddress,
  ethers.utils.parseEther("100000"), // 100,000 tokens
  startTime,
  oneYearInSeconds, // 1 year duration
  true, // Revocable
  ethers.id("TEAM_ALLOCATION") // Metadata
);
await tx.wait();
```

### Release Vested Tokens

```javascript
// Release available tokens from a vesting schedule
const tx = await vestingContract.release(vestingScheduleId);
await tx.wait();
```

### Handle Emergency Situations

```javascript
// Declare an emergency (admin only)
const tx = await emergencyRecoveryContract.declareEmergency(
  2, // Level 2 emergency
  "Vulnerability detected in token transfer function"
);
await tx.wait();

// Approve emergency action (multisig signers)
const tx = await emergencyRecoveryContract.approveEmergencyAction(emergencyActionId);
await tx.wait();

// Recover tokens (after approval)
const tx = await emergencyRecoveryContract.recoverERC20(
  tokenAddress,
  contractWithStuckTokens,
  ethers.utils.parseEther("1000") // Amount to recover
);
await tx.wait();
```

## Upgrading Contracts

To upgrade the token implementation:

```bash
# Set environment variables
export PROXY_ADDRESS=0x...

# Run upgrade script
npx hardhat run scripts/upgrade-token.js --network <network-name>
```

## Architecture Diagrams

### Core System Flow
```
┌─────────────┐     ┌───────────────┐     ┌─────────────┐
│  EducToken  │◄────┤ EducLearning  │────►│ EducStudent │
└─────┬───────┘     └───────┬───────┘     └──────┬──────┘
      │                     │                    │
      │                     ▼                    │
      │             ┌───────────────┐            │
      └────────────┤  EducCourse   │◄───────────┘
                   └───────┬───────┘
                           │
                           ▼
                   ┌───────────────┐
                   │ EducEducator  │
                   └───────────────┘
```

### Governance and Security
```
┌─────────────┐     ┌───────────────┐     ┌────────────────────┐
│ EducPause   │◄────┤ EducMultisig  │────►│ EducEmergencyRecovery │
└─────────────┘     └───────┬───────┘     └────────────────────┘
                            │
                            ▼
                    ┌───────────────┐
                    │ EducProposal  │
                    └───────────────┘
```

### Vesting System
```
┌─────────────────┐     ┌───────────────┐
│ EducVestingFactory │──►│ EducVesting 1 │
└─────────────────┘     └───────────────┘
                        ┌───────────────┐
                        │ EducVesting 2 │
                        └───────────────┘
                        ┌───────────────┐
                        │ EducVesting N │
                        └───────────────┘
```

## Contract Security

- All contracts use OpenZeppelin's secure implementation patterns
- Critical functions are protected with access control and pausability
- Reentrancy guards on functions that transfer value
- Comprehensive input validation
- Emergency pause and recovery mechanisms

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Security Vulnerabilities

If you discover a security vulnerability within this project, please send an email to security@eductoken.com. All security vulnerabilities will be promptly addressed.