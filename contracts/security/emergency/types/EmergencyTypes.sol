// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title EmergencyTypes
 * @dev Defines type structures for the Emergency module
 */
library EmergencyTypes {
    /**
     * @dev Represents emergency levels in the system
     */
    enum EmergencyLevel {
        None,       // No emergency
        Level1,     // Minor issue, requires monitoring
        Level2,     // Moderate issue, requires restrictions
        Level3,     // Critical issue, emergency mode activated
        Resolved    // Emergency resolved
    }
    
    /**
     * @dev Tracks an emergency action
     */
    struct EmergencyAction {
        uint256 id;                  // Unique identifier for the action
        EmergencyLevel level;        // Severity level
        address triggeredBy;         // Address that triggered the emergency
        uint256 timestamp;           // When the emergency was triggered
        string reason;               // Reason for the emergency
        bool isActive;               // Whether the emergency is still active
        uint256 resolvedAt;          // When the emergency was resolved (0 if not resolved)
        address resolvedBy;          // Address that resolved the emergency (0x0 if not resolved)
    }
    
    /**
     * @dev Manages recovery configuration
     */
    struct RecoveryConfig {
        address treasury;            // Treasury address for recovered funds
        address systemContract;      // Main system contract (EducLearning)
        uint256 cooldownPeriod;      // Cooldown between recoveries
        uint256 approvalThreshold;   // Required approvals for recoveries
    }
    
    /**
     * @dev Parameters for declaring an emergency
     */
    struct EmergencyDeclarationParams {
        EmergencyLevel level;        // Emergency level to declare
        string reason;               // Reason for the emergency
    }
    
    /**
     * @dev Parameters for recovering ERC20 tokens
     */
    struct TokenRecoveryParams {
        address token;               // Token address
        address from;                // Contract address where tokens are stuck
        uint256 amount;              // Amount to recover
    }
    
    /**
     * @dev Parameters for updating recovery configuration
     */
    struct RecoveryConfigUpdateParams {
        address treasury;            // New treasury address
        address systemContract;      // New system contract address
        uint256 cooldownPeriod;      // New cooldown period
        uint256 approvalThreshold;   // New approval threshold
    }
}