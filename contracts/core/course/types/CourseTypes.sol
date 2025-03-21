// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title CourseTypes
 * @dev Defines type structures for the Course module
 */
library CourseTypes {
    /**
     * @dev Represents a course in the system
     */
    struct Course {
        // Core properties
        string courseId;             // Unique identifier for the course
        string courseName;           // Name of the course
        address educator;            // Address of the course educator
        uint256 rewardAmount;        // Tokens rewarded for completion
        
        // Status and counts
        uint32 completionCount;      // Number of students who completed the course
        bool isActive;               // Whether the course is currently active
        
        // Metadata
        bytes32 metadataHash;        // Hash of additional course metadata
        
        // Timestamps
        uint256 createdAt;           // When the course was created
        uint256 lastUpdatedAt;       // When the course was last updated
        uint256 lastCompletionTimestamp; // Last time a student completed this course
        
        // Version tracking
        uint32 version;              // Version number, incremented on updates
    }
    
    /**
     * @dev Course history entry for tracking changes
     */
    struct CourseHistory {
        string courseId;             // ID of the course
        address educator;            // Address of the course educator
        uint32 version;              // Version number for this history entry
        string previousName;         // Previous course name
        uint256 previousReward;      // Previous reward amount
        bool previousActive;         // Previous active status
        bytes32 previousMetadataHash; // Previous metadata hash
        address updatedBy;           // Address that made the update
        uint256 updatedAt;           // When the update occurred
        string changeDescription;    // Description of the changes made
    }
    
    /**
     * @dev Parameters for creating a new course
     */
    struct CourseCreationParams {
        string courseId;             // Unique identifier for the course
        string courseName;           // Name of the course 
        uint256 rewardAmount;        // Tokens rewarded for completion
        bytes32 metadataHash;        // Hash of additional course metadata
    }
    
    /**
     * @dev Parameters for updating an existing course
     */
    struct CourseUpdateParams {
        string courseId;             // ID of the course to update
        string courseName;           // Optional new name (empty to keep current)
        uint256 rewardAmount;        // Optional new reward amount (0 to keep current)
        bool isActive;               // New active status
        bytes32 metadataHash;        // Optional new metadata hash (bytes32(0) to keep current)
        string changeDescription;    // Description of the changes
    }
}