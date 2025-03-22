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

## Project Structure

```
eductoken/
├── contracts/
│   ├── access/
│   │   ├── EducAccess.sol
│   │   └── roles/
│   │       └── EducRoles.sol
│   ├── config/
│   │   ├── EducConfig.sol
│   │   └── constants/
│   │       └── SystemConstants.sol
│   ├── core/
│   │   ├── token/
│   │   │   ├── EducToken.sol
│   │   │   ├── EducTokenWithRecovery.sol
│   │   │   ├── TokenEvents.sol
│   │   │   └── types/
│   │   │       └── TokenTypes.sol
│   │   ├── educator/
│   │   │   ├── EducEducator.sol
│   │   │   ├── EducatorEvents.sol
│   │   │   └── types/
│   │   │       └── EducatorTypes.sol
│   │   ├── student/
│   │   │   ├── EducStudent.sol
│   │   │   ├── StudentEvents.sol
│   │   │   └── types/
│   │   │       └── StudentTypes.sol
│   │   └── course/
│   │       ├── EducCourse.sol
│   │       ├── CourseEvents.sol
│   │       └── types/
│   │           └── CourseTypes.sol
│   ├── governance/
│   │   ├── multisig/
│   │   │   ├── EducMultisig.sol
│   │   │   └── MultisigEvents.sol
│   │   └── proposal/
│   │       ├── EducProposal.sol
│   │       ├── ProposalEvents.sol
│   │       └── types/
│   │           └── ProposalTypes.sol
│   ├── interfaces/
│   │   ├── IEducToken.sol
│   │   ├── IEducStudent.sol
│   │   ├── IEducEducator.sol
│   │   ├── IEducCourse.sol
│   │   ├── IEducLearning.sol
│   │   ├── IEducConfig.sol
│   │   ├── IEducPause.sol
│   │   ├── IEducMultisig.sol
│   │   ├── IEducProposal.sol
│   │   ├── IEducVesting.sol
│   │   └── IEducEmergencyRecovery.sol
│   ├── proxy/
│   │   ├── EducTokenUpgradeable.sol
│   │   └── interfaces/
│   │       └── IUpgradeable.sol
│   ├── security/
│   │   ├── emergency/
│   │   │   ├── EducEmergencyEnabled.sol
│   │   │   ├── EducEmergencyRecovery.sol
│   │   │   ├── EmergencyEvents.sol
│   │   │   └── types/
│   │   │       └── EmergencyTypes.sol
│   │   └── pause/
│   │       ├── EducPause.sol
│   │       ├── PauseEvents.sol
│   │       └── types/
│   │           └── PauseTypes.sol
│   └── vesting/
│       ├── EducVesting.sol
│       ├── EducVestingCloneable.sol
│       ├── EducVestingFactory.sol
│       ├── VestingEvents.sol
│       └── types/
│           └── VestingTypes.sol
├── scripts/
│   ├── create-token-snapshot.js
│   ├── deploy.js
│   ├── deploy-upgradeable.js
│   ├── migrate-to-recovery.js
│   ├── upgrade-token.js
│   ├── verify.js
│   └── verify-proxy.js
├── test/
│   ├── index.js
│   ├── unit/
│   │   ├── EducToken_unit.test.js
│   │   ├── EducEducator_unit.test.js
│   │   ├── EducStudent_unit.test.js
│   │   ├── EducCourse_unit.test.js
│   │   ├── EducConfig_unit.test.js
│   │   ├── EducPause_unit.test.js
│   │   ├── EducMultisig_unit.test.js
│   │   ├── EducProposal_unit.test.js
│   │   └── EducLearning_unit.test.js
│   └── integration/
│       └── ... (integration tests)
├── hardhat.config.js
├── package.json
├── .solhint.json
├── .gitignore
├── MIGRATION_GUIDE.md
└── README.md
```

## Technical Specifications

- **Blockchain**: Ethereum
- **Language**: Solidity ^0.8.19
- **Framework**: Hardhat
- **Libraries**: OpenZeppelin Contracts 5.2.0, OpenZeppelin Contracts Upgradeable 5.2.0
- **Testing**: Mocha, Chai

## Requirements

### Development Environment
- Node.js (v16+)
- npm or yarn
- Git
- 4GB+ RAM recommended
- Stable internet connection

### External Services
- Ethereum RPC Provider (Infura, Alchemy, etc.)
- Etherscan API Key (for contract verification)
- MetaMask or other Ethereum wallet

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
# or
npx hardhat
```

3. Create environment file:
```bash
cp .env.example .env
```

4. Configure your `.env` file with the following variables:
```
# Network RPC URLs (replace YOUR-API-KEY with your actual API key)
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR-API-KEY
HOLESKY_RPC_URL=https://eth-holesky.g.alchemy.com/v2/YOUR-API-KEY
MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR-API-KEY

# API Configurations
ETHERSCAN_API_URL=https://api.etherscan.io/api
ETHERSCAN_API_KEY=YOUR-ETHERSCAN-API-KEY
COINMARKETCAP_API_KEY=YOUR-COINMARKETCAP-API-KEY

# Wallet
PRIVATE_KEY=YOUR-PRIVATE-KEY-WITHOUT-0x-PREFIX

# Gas Reporting
REPORT_GAS=true
```

> **IMPORTANT SECURITY NOTE**: 
> - Never commit your `.env` file to version control
> - Keep your private key secure and never share it
> - For added security, consider using environment variables or a vault for production deployments
> - Ensure `.env` is included in your `.gitignore` file

### Compilation

Compile the contracts:
```bash
npm run compile
# or
yarn compile
# or
npx hardhat compile
```

### Testing

Run the test suite:
```bash
npm run test
# or
yarn test
# or
npx hardhat test
```

Generate test coverage report:
```bash
npm run coverage
# or
yarn coverage
# or
npx hardhat coverage
```

## Unit Tests

The project includes comprehensive unit tests for all core contracts. The test suite is organized by contract and covers all essential functionality.

### Test Structure

- **Index File**: `test/index.js` loads all unit tests in sequence
- **Test Directory**: `test/unit/` contains individual test files for each contract

### Core Contract Tests

1. **EducToken Tests**:
   - Token deployment and initialization
   - Role management (admin, minter)
   - Minting functionality with daily limits
   - Educational rewards and batch minting
   - Token burning mechanisms
   - Pausing functionality
   - Student contract integration
   - Account inactivity detection

2. **EducEducator Tests**:
   - Educator registration and validation
   - Status management
   - Mint tracking
   - Course count management
   - Role-based access control

3. **EducStudent Tests**:
   - Student registration and validation
   - Course completion recording
   - Token usage tracking
   - Activity categories management
   - Student activity monitoring
   - Inactivity detection
   - Comprehensive student querying

4. **EducCourse Tests**:
   - Course creation and validation
   - Course updates and version tracking
   - Course completion counting
   - Integration with EducEducator
   - Course querying functions
   - Pause functionality

5. **EducConfig Tests**:
   - Configuration initialization
   - Parameter updates and validation
   - Configuration access control
   - Constraint enforcement
   - Pause functionality

6. **EducPause Tests**:
   - Emergency pause controls
   - Granular function pausing
   - Pause overrides by address
   - Pause history tracking
   - Role-based access control for pause functions

7. **EducMultisig Tests**:
   - Multisig initialization with signers and threshold
   - Signer management (adding, removing)
   - Threshold management
   - Proposal count tracking
   - Signer verification and validation

8. **EducProposal Tests**:
   - Proposal creation and validation
   - Voting mechanisms (approval, rejection)
   - Automatic execution when threshold met
   - Proposal expiration handling
   - Proposal status tracking
   - Role-based access control

9. **EducLearning Tests**:
   - System initialization and component integration
   - Course completion processing
   - Educational reward distribution
   - Batch reward issuance
   - Burning inactive tokens
   - Daily minting limit management
   - Pause controls

### Running Specific Tests

To run tests for a specific contract:

```bash
npx hardhat test test/unit/EducToken_unit.test.js
```

To run all tests with gas usage reporting:

```bash
REPORT_GAS=true npx hardhat test
```

To run tests with coverage:

```bash
npx hardhat coverage
```

### Deployment

1. Start a local node for development:
```bash
npm run node
# or
yarn node
# or
npx hardhat node
```

2. Deploy to local development network:
```bash
npm run deploy:local
# or
yarn deploy:local
# or
npx hardhat run scripts/deploy.js --network localhost
```

3. Deploy to Sepolia testnet:
```bash
npm run deploy:sepolia
# or
yarn deploy:sepolia
# or
npx hardhat run scripts/deploy.js --network sepolia
```

### Deploying Advanced Features

#### Upgradeable Token System

Deploy the upgradeable token system:
```bash
npm run deploy:upgradeable
# or
yarn deploy:upgradeable
# or
npx hardhat run scripts/deploy-upgradeable.js --network <network-name>
```

#### Vesting System

Deploy the vesting system:
```bash
npm run deploy:vesting
# or
yarn deploy:vesting
# or
npx hardhat run scripts/deploy-vesting.js --network <network-name>
```

#### Emergency Recovery System

Deploy or migrate to the emergency recovery system:
```bash
npm run migrate:recovery
# or
yarn migrate:recovery
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
# or
npx hardhat verify --network <network-name> --contract <contract-path:ContractName> <deployed-address> <constructor-args>

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
  ethers.parseEther("50") // Amount to burn
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
      │            ┌───────────────┐             │
      └────────────┤  EducCourse   │◄────────────┘
                   └───────┬───────┘
                           │
                           ▼
                   ┌───────────────┐
                   │ EducEducator  │
                   └───────────────┘
```

### Governance and Security
```
┌─────────────┐     ┌───────────────┐     ┌───────────────────────┐
│ EducPause   │◄────┤ EducMultisig  │────►│ EducEmergencyRecovery │
└─────────────┘     └───────┬───────┘     └───────────────────────┘
                            │
                            ▼
                    ┌───────────────┐
                    │ EducProposal  │
                    └───────────────┘
```

### Vesting System
```
┌───────────────────┐     ┌───────────────┐
│ EducVestingFactory│──►  │ EducVesting 1 │
└───────────────────┘     └───────────────┘
                          ┌───────────────┐
                          │ EducVesting 2 │
                          └───────────────┘
                          ┌───────────────┐
                          │ EducVesting N │
                          └───────────────┘
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

4. **Network Connection Problems**:
   - Check your RPC endpoint URL in `.env` file
   - Ensure you have sufficient ETH for gas fees

5. **Contract Verification Errors**:
   - Confirm you're using the exact compiler version
   - Check that constructor arguments match exactly

6. **Environment File Issues**:
   - Ensure all required variables are defined in `.env`
   - Check API keys are active and valid
   - Verify RPC URLs are accessible

### Solutions

If you encounter the "cannot estimate gas" error, try:
```bash
npx hardhat run scripts/deploy.js --network <network-name> --gas-price 50000000000
```

For contract size errors:
```bash
# Enable IR compiler optimization in hardhat.config.js
# Set viaIR: true in the compiler settings
```

For `.env` file issues:
```bash
# Verify .env variables are loaded
npx hardhat run --network sepolia scripts/check-env.js
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.