# EducToken: Educational Incentives Token

EducToken is an ERC20 token designed for a decentralized educational incentive system, allowing educators to issue tokens as rewards for students who complete courses, participate in activities, or achieve specific educational milestones.

## Project Overview

This project implements a complete token-based educational reward system on Ethereum, with role-based access control, course management, student tracking, and governance features.

## Key Features

- **ERC20 Token Implementation**
  - Total Supply: 10,000,000 EDUC
  - Controlled minting for educational rewards
  - Burning mechanism for expired tokens

- **Role-Based Access Control**
  - Admin role for system management
  - Educator role for course creation and rewards
  - Governance through multisignature proposals

- **Course Management**
  - Create and update courses
  - Set reward amounts per course
  - Track course completions

- **Student Tracking**
  - Record course completions
  - Track token earnings
  - Maintain educational history

- **Security Features**
  - Pausable operations
  - Granular pause control
  - Emergency multisignature governance

## System Architecture

### Core Contracts

- **EducToken**: ERC20 token with minting and burning capabilities
- **EducEducator**: Manages educator registrations and permissions
- **EducStudent**: Tracks student registrations and course completions
- **EducCourse**: Handles course creation and management
- **EducLearning**: Main contract that integrates all components

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

### Testing

Run the test suite:
```bash
npm test
# or
yarn test
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

4. Verify contracts on Etherscan:
   - Update the addresses in `scripts/verify.js`
   - Run:
```bash
npm run verify
# or
yarn verify
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

### Create a Course

```javascript
const tx = await courseContract.createCourse(
  "CS101",                       // Course ID
  "Introduction to Blockchain",  // Course name
  ethers.utils.parseEther("10"), // Reward amount (10 tokens)
  ethers.utils.id("metadata")    // Metadata hash
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

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.