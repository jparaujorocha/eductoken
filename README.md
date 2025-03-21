# EducToken: Educational Incentives Token

EducToken is an ERC20 token designed for a decentralized educational incentive system, allowing educators to issue tokens as rewards for students who complete courses, participate in activities, or achieve specific educational milestones.

## Project Overview

This project implements a complete token-based educational reward system on Ethereum, with role-based access control, course management, student tracking, activity monitoring, and governance features.

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

## Technical Specifications

- **Blockchain**: Ethereum
- **Language**: Solidity ^0.8.19
- **Framework**: Hardhat
- **Libraries**: OpenZeppelin Contracts 4.9.3
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

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.