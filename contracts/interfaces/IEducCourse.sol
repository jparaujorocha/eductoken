// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IEducCourse
 * @dev Interface for the EducCourse contract
 */
interface IEducCourse {
    /**
     * @dev Creates a new course
     * @param courseId Unique identifier for the course
     * @param courseName Name of the course
     * @param rewardAmount Amount of tokens rewarded for completion
     * @param metadataHash Hash of additional course metadata
     */
    function createCourse(
        string calldata courseId,
        string calldata courseName,
        uint256 rewardAmount,
        bytes32 metadataHash
    ) external;

    /**
     * @dev Updates an existing course
     * @param courseId ID of the course to update
     * @param courseName Optional new name for the course (empty string to keep current)
     * @param rewardAmount Optional new reward amount (0 to keep current)
     * @param isActive Optional new active status
     * @param metadataHash Optional new metadata hash (bytes32(0) to keep current)
     * @param changeDescription Description of the changes
     */
    function updateCourse(
        string calldata courseId,
        string calldata courseName,
        uint256 rewardAmount,
        bool isActive,
        bytes32 metadataHash,
        string calldata changeDescription
    ) external;

    /**
     * @dev Increments the completion count for a course
     * @param educator Address of the course educator
     * @param courseId ID of the completed course
     */
    function incrementCompletionCount(address educator, string calldata courseId) external;

    /**
     * @dev Gets course data
     * @param educator Address of the course educator
     * @param courseId ID of the course
     * @return Course data fields (courseId, courseName, educator, rewardAmount, completionCount, 
     *         isActive, metadataHash, createdAt, lastUpdatedAt, version)
     */
    function getCourse(address educator, string calldata courseId) 
        external 
        view 
        returns (
            string memory,
            string memory,
            address,
            uint256,
            uint32,
            bool,
            bytes32,
            uint256,
            uint256,
            uint32
        );

    /**
     * @dev Checks if a course exists and is active
     * @param educator Address of the course educator
     * @param courseId ID of the course
     * @return bool True if the course exists and is active
     */
    function isCourseActive(address educator, string calldata courseId) external view returns (bool);

    /**
     * @dev Gets the reward amount for a course
     * @param educator Address of the course educator
     * @param courseId ID of the course
     * @return uint256 The reward amount for the course
     */
    function getCourseReward(address educator, string calldata courseId) external view returns (uint256);

    /**
     * @dev Gets the total number of courses
     * @return uint256 The total number of courses
     */
    function getTotalCourses() external view returns (uint256);
}