// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title StudentTypes
 * @dev Defines type structures for the Student module
 */
library StudentTypes {
    /**
     * @dev Represents a student in the system
     */
    struct Student {
        address studentAddress;      // The student's address
        uint256 totalEarned;         // Total tokens earned by the student
        uint32 coursesCompleted;     // Number of courses completed
        uint256 lastActivity;        // Timestamp of the last activity
        uint256 registrationTimestamp; // When the student was registered
    }
    
    /**
     * @dev Records a course completion for a student
     */
    struct CourseCompletion {
        address student;             // Address of the student
        string courseId;             // ID of the completed course
        address verifiedBy;          // Address that verified the completion
        uint256 completionTime;      // When the course was completed
        uint256 tokensAwarded;       // Amount of tokens awarded for completion
        bytes32 additionalMetadata;  // Any additional metadata for the completion
    }
    
    /**
     * @dev Parameters for registering a new student
     */
    struct StudentRegistrationParams {
        address studentAddress;      // Address to register as a student
    }
    
    /**
     * @dev Parameters for recording a course completion
     */
    struct CourseCompletionParams {
        address studentAddress;      // Address of the student
        string courseId;             // ID of the completed course
        uint256 tokensAwarded;       // Amount of tokens awarded
    }
    
    /**
     * @dev Parameters for recording token usage by a student
     */
    struct TokenUsageParams {
        address studentAddress;      // Address of the student
        uint256 tokensUsed;          // Amount of tokens used
        string purpose;              // Purpose of token usage
    }
    
    /**
     * @dev Parameters for recording a custom student activity
     */
    struct CustomActivityParams {
        address studentAddress;      // Address of the student
        string category;             // Activity category
        string details;              // Activity details
    }
}