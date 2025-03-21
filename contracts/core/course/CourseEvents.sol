// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title CourseEvents
 * @dev Defines events for the Course module
 */
library CourseEvents {
    /**
     * @dev Emitted when a new course is created
     * @param courseId Unique identifier for the course
     * @param courseName Name of the course
     * @param educator Address of the course educator
     * @param rewardAmount Tokens rewarded for completion
     * @param timestamp When the course was created
     */
    event CourseCreated(
        string courseId,
        string courseName,
        address indexed educator,
        uint256 rewardAmount,
        uint256 timestamp
    );

    /**
     * @dev Emitted when a course is updated
     * @param courseId ID of the updated course
     * @param educator Address of the course educator
     * @param version New version number
     * @param previousName Previous course name
     * @param newName New course name
     * @param previousReward Previous reward amount
     * @param newReward New reward amount
     * @param previousActive Previous active status
     * @param newActive New active status
     * @param updatedBy Address that made the update
     * @param timestamp When the update occurred
     */
    event CourseUpdated(
        string courseId,
        address indexed educator,
        uint32 version,
        string previousName,
        string newName,
        uint256 previousReward,
        uint256 newReward,
        bool previousActive,
        bool newActive,
        address updatedBy,
        uint256 timestamp
    );

    /**
     * @dev Emitted when a course completion is tracked
     * @param courseId ID of the completed course
     * @param educator Address of the course educator
     * @param completionCount Updated number of completions
     * @param timestamp When the completion was recorded
     */
    event CourseCompletionTracked(
        string courseId,
        address indexed educator,
        uint32 completionCount,
        uint256 timestamp
    );
    
    /**
     * @dev Emitted when a course metadata is updated
     * @param courseId ID of the updated course
     * @param educator Address of the course educator
     * @param previousMetadataHash Previous metadata hash
     * @param newMetadataHash New metadata hash
     * @param timestamp When the metadata was updated
     */
    event CourseMetadataUpdated(
        string courseId,
        address indexed educator,
        bytes32 previousMetadataHash,
        bytes32 newMetadataHash,
        uint256 timestamp
    );
}