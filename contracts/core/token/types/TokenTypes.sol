// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title TokenTypes
 * @dev Defines type structures for the Token module
 */
library TokenTypes {
    /**
     * @dev Parameters for minting tokens as educational rewards to a single recipient
     */
    struct MintRewardParams {
        address student;             // The student address to receive tokens
        uint256 amount;              // Amount of tokens to mint
        string reason;               // Educational reason for the reward
    }
    
    /**
     * @dev Parameters for batch minting tokens as educational rewards
     */
    struct BatchMintRewardParams {
        address[] students;          // Student addresses
        uint256[] amounts;           // Token amounts for each student
        string[] reasons;            // Educational reasons for each reward
    }
    
    /**
     * @dev Parameters for burning tokens from inactive accounts
     */
    struct BurnInactiveParams {
        address from;                // Address of the inactive account
        uint256 amount;              // Amount of tokens to burn
        string reason;               // Reason for burning the tokens
    }
    
    /**
     * @dev Records a token minting operation
     */
    struct MintRecord {
        address recipient;           // Address that received the tokens
        address minter;              // Address that performed the minting
        uint256 amount;              // Amount of tokens minted
        string reason;               // Reason for the minting
        uint256 timestamp;           // When the minting occurred
    }
    
    /**
     * @dev Records a token burning operation
     */
    struct BurnRecord {
        address from;                // Address tokens were burned from
        address burner;              // Address that performed the burning (if not self)
        uint256 amount;              // Amount of tokens burned
        string reason;               // Reason for the burning
        uint256 timestamp;           // When the burning occurred
    }
}