// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title StudentEvents
 * @dev Defines events for the Student module
 */
library StudentEvents {
    /**
     * @dev Emitted when a new student is registered
     * @param student Address of the registered student
     * @param registrationTimestamp When the student was registered
     */
    event StudentRegistered(
        address indexed student,
        uint256 registrationTimestamp
    );

    /**
     * @dev Emitted when a course completion is recorded
     * @param student Address of the student
     * @param courseId ID of the completed course
     * @param educator Address of the course educator
     * @param tokensAwarded Amount of tokens awarded for completion
     * @param completionTimestamp When the completion was recorded
     */
    event CourseCompletionRecorded(
        address indexed student,
        string courseId,
        address indexed educator,
        uint256 tokensAwarded,
        uint256 completionTimestamp
    );

    /**
     * @dev Emitted when a student activity is recorded
     * @param student Address of the student
     * @param actionType Type of activity
     * @param timestamp When the activity occurred
     */
    event StudentActivityUpdated(
        address indexed student,
        string actionType,
        uint256 timestamp
    );
    
    /**
     * @dev Emitted when a new activity category is added for a student
     * @param student Address of the student
     * @param categoryName Name of the new category
     * @param timestamp When the category was added
     */
    event StudentActivityCategoryAdded(
        address indexed student,
        string categoryName,
        uint256 timestamp
    );
    
    /**
     * @dev Emitted when tokens are used by a student
     * @param student Address of the student
     * @param tokensUsed Amount of tokens used
     * @param purpose Purpose of token usage
     * @param timestamp When the tokens were used
     */
    event StudentTokensUsed(
        address indexed student,
        uint256 tokensUsed,
        string purpose,
        uint256 timestamp
    );
    
    /**
     * @dev Emitted when a student is detected as inactive
     * @param student Address of the student
     * @param lastActivityTimestamp Last recorded activity timestamp
     * @param detectionTimestamp When the inactivity was detected
     */
    event StudentInactivityDetected(
        address indexed student,
        uint256 lastActivityTimestamp,
        uint256 detectionTimestamp
    );
}