// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title VestingTypes
 * @dev Defines type structures for the Vesting module
 */
library VestingTypes {
    /**
     * @dev Vesting types supported by the system
     */
    enum VestingType {
        Linear,     // Steady release over time
        Cliff,      // Nothing until a point, then everything
        Milestone,  // Release based on specific education milestones
        Hybrid      // Combination of cliff and linear
    }

    /**
     * @dev Represents a vesting schedule
     */
    struct VestingSchedule {
        address beneficiary;        // Address receiving tokens
        uint256 totalAmount;        // Total tokens allocated
        uint256 released;           // Tokens already released
        uint256 startTime;          // Schedule start timestamp
        uint256 duration;           // Duration in seconds
        uint256 cliffDuration;      // Duration of cliff period (if applicable)
        uint32 milestoneCount;      // Number of milestones (if applicable)
        uint32 milestonesReached;   // Number of reached milestones (if applicable)
        bool revocable;             // Whether the schedule can be revoked
        bool revoked;               // Whether the schedule was revoked
        VestingType vestingType;    // Type of vesting schedule
        bytes32 metadata;           // Additional schedule details
    }
    
    /**
     * @dev Parameters for creating a linear vesting schedule
     */
    struct LinearVestingParams {
        address beneficiary;        // Recipient of vested tokens
        uint256 totalAmount;        // Total amount of tokens
        uint256 startTime;          // Schedule start time
        uint256 duration;           // Duration in seconds
        bool revocable;             // Whether the schedule can be revoked
        bytes32 metadata;           // Additional metadata hash
    }
    
    /**
     * @dev Parameters for creating a cliff vesting schedule
     */
    struct CliffVestingParams {
        address beneficiary;        // Recipient of vested tokens
        uint256 totalAmount;        // Total amount of tokens
        uint256 startTime;          // Schedule start time
        uint256 cliffDuration;      // Cliff duration in seconds
        bool revocable;             // Whether the schedule can be revoked
        bytes32 metadata;           // Additional metadata hash
    }
    
    /**
     * @dev Parameters for creating a hybrid vesting schedule
     */
    struct HybridVestingParams {
        address beneficiary;        // Recipient of vested tokens
        uint256 totalAmount;        // Total amount of tokens
        uint256 startTime;          // Schedule start time
        uint256 duration;           // Total duration in seconds
        uint256 cliffDuration;      // Cliff duration in seconds
        bool revocable;             // Whether the schedule can be revoked
        bytes32 metadata;           // Additional metadata hash
    }
    
    /**
     * @dev Parameters for creating a milestone-based vesting schedule
     */
    struct MilestoneVestingParams {
        address beneficiary;        // Recipient of vested tokens
        uint256 totalAmount;        // Total amount of tokens
        uint256 startTime;          // Schedule start time
        uint256 duration;           // Maximum duration in seconds
        uint32 milestoneCount;      // Number of required milestones
        bool revocable;             // Whether the schedule can be revoked
        bytes32 metadata;           // Additional metadata hash
    }
}