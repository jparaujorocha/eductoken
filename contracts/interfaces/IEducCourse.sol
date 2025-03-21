// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../core/course/types/CourseTypes.sol";

/**
 * @title IEducCourse
 * @dev Interface for the EducCourse contract
 */
interface IEducCourse {
    /**
     * @dev Creates a new course
     * @param params Course creation parameters
     */
    function createCourse(CourseTypes.CourseCreationParams calldata params) external;

    /**
     * @dev Legacy method for compatibility - creates a new course
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
     * @param params Course update parameters
     */
    function updateCourse(CourseTypes.CourseUpdateParams calldata params) external;

    /**
     * @dev Legacy method for compatibility - updates an existing course
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
     * @return course The course data as a structured object
     */
    function getCourseInfo(address educator, string calldata courseId) 
        external 
        view 
        returns (CourseTypes.Course memory course);
        
    /**
     * @dev Legacy method for compatibility - gets course data
     * @param educator Address of the course educator
     * @param courseId ID of the course
     * @return courseId ID of the course
     * @return courseName Name of the course
     * @return educator Address of the course educator
     * @return rewardAmount Amount of tokens rewarded for completion
     * @return completionCount Number of students who completed the course
     * @return isActive Whether the course is currently active
     * @return metadataHash Hash of additional course metadata
     * @return createdAt When the course was created
     * @return lastUpdatedAt When the course was last updated
     * @return version Version number, incremented on updates
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
     * @return active True if the course exists and is active
     */
    function isCourseActive(address educator, string calldata courseId) external view returns (bool active);

    /**
     * @dev Gets the reward amount for a course
     * @param educator Address of the course educator
     * @param courseId ID of the course
     * @return reward The reward amount for the course
     */
    function getCourseReward(address educator, string calldata courseId) external view returns (uint256 reward);

    /**
     * @dev Gets the total number of courses
     * @return total The total number of courses
     */
    function getTotalCourses() external view returns (uint256 total);
    
    /**
     * @dev Gets course history for a specific version
     * @param educator Address of the course educator
     * @param courseId ID of the course
     * @param version Version number to retrieve
     * @return history The course history entry for the specified version
     */
    function getCourseHistory(address educator, string calldata courseId, uint32 version) 
        external 
        view 
        returns (CourseTypes.CourseHistory memory history);
    
    /**
     * @dev Gets the number of history entries for a course
     * @param educator Address of the course educator
     * @param courseId ID of the course
     * @return count The number of history entries
     */
    function getCourseHistoryCount(address educator, string calldata courseId) 
        external 
        view 
        returns (uint256 count);
}