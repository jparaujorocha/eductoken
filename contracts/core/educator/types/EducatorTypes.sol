// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title EducatorTypes
 * @dev Defines type structures for the Educator module
 */
library EducatorTypes {
    /**
     * @dev Represents an educator in the system
     */
    struct Educator {
        // Core properties
        address educatorAddress;     // The educator's address
        address authorityAddress;    // Address that authorized this educator
        
        // Minting and limits
        uint256 mintLimit;           // Maximum tokens the educator can mint
        uint256 totalMinted;         // Total amount of tokens minted by this educator
        uint256 lastMintTime;        // Last time the educator minted tokens
        
        // Course management
        uint16 courseCount;          // Number of courses created by this educator
        
        // Status tracking
        bool isActive;               // Whether the educator is currently active
        
        // Timestamps
        uint256 createdAt;           // When the educator was registered
        uint256 lastUpdatedAt;       // When the educator was last updated
    }
    
    /**
     * @dev Parameters for registering a new educator
     */
    struct EducatorRegistrationParams {
        address educatorAddress;     // Address to register as educator
        uint256 mintLimit;           // Maximum tokens the educator can mint
    }
    
    /**
     * @dev Parameters for updating an educator's status
     */
    struct EducatorStatusUpdateParams {
        address educatorAddress;     // Address of the educator to update
        bool isActive;               // New active status
        uint256 newMintLimit;        // Optional new mint limit (0 to keep current)
    }
    
    /**
     * @dev Record of an educator's minting activity
     */
    struct MintRecord {
        address educatorAddress;     // Educator that performed the minting
        uint256 amount;              // Amount of tokens minted
        uint256 timestamp;           // When the minting occurred
    }
}