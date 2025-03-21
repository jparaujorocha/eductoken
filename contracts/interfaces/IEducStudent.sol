// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IEducStudent
 * @dev Interface for the EducStudent contract with enhanced activity tracking
 */
interface IEducStudent {
    /**
     * @dev Registers a new student
     * @param student Address of the student to register
     */
    function registerStudent(address student) external;

    /**
     * @dev Records a course completion for a student
     * @param student Address of the student
     * @param courseId ID of the completed course
     * @param tokensAwarded Amount of tokens awarded for completion
     */
    function recordCourseCompletion(
        address student,
        string calldata courseId,
        uint256 tokensAwarded
    ) external;
    
    /**
     * @dev Records a student token usage activity
     * @param student Address of the student
     * @param tokensUsed Amount of tokens used
     * @param purpose Purpose of token usage
     */
    function recordTokenUsage(
        address student, 
        uint256 tokensUsed, 
        string calldata purpose
    ) external;
    
    /**
     * @dev Adds a custom activity category for a student
     * @param student Address of the student
     * @param category New activity category name
     */
    function addActivityCategory(address student, string calldata category) external;
    
    /**
     * @dev Records a custom activity for a student
     * @param student Address of the student
     * @param category Activity category
     * @param details Activity details
     */
    function recordCustomActivity(
        address student,
        string calldata category,
        string calldata details
    ) external;

    /**
     * @dev Checks if a student has completed a specific course
     * @param student Address of the student
     * @param courseId ID of the course to check
     * @return bool True if the student has completed the course
     */
    function hasCourseCompletion(address student, string calldata courseId) 
        external 
        view 
        returns (bool);

    /**
     * @dev Gets a student's total earned tokens
     * @param student Address of the student
     * @return uint256 The total tokens earned by the student
     */
    function getStudentTotalEarned(address student) external view returns (uint256);

    /**
     * @dev Gets the number of courses completed by a student
     * @param student Address of the student
     * @return uint32 The number of courses completed
     */
    function getStudentCoursesCompleted(address student) external view returns (uint32);

    /**
     * @dev Gets the last activity timestamp for a student
     * @param student Address of the student
     * @return uint256 The timestamp of the student's last activity
     */
    function getStudentLastActivity(address student) external view returns (uint256);
    
    /**
     * @dev Gets the last activity timestamp for a student in a specific category
     * @param student Address of the student
     * @param category Activity category
     * @return uint256 The timestamp of the last activity in the category
     */
    function getStudentLastActivityByCategory(address student, string calldata category)
        external
        view
        returns (uint256);
    
    /**
     * @dev Gets all activity categories for a student
     * @param student Address of the student
     * @return Array of activity category names
     */
    function getStudentActivityCategories(address student)
        external
        view
        returns (string[] memory);

    /**
     * @dev Checks if a student is registered
     * @param student Address to check
     * @return bool True if the address is a registered student
     */
    function isStudent(address student) external view returns (bool);
    
    /**
     * @dev Checks if a student is considered inactive
     * @param student Address of the student
     * @return bool True if the student is inactive
     */
    function isStudentInactive(address student) external view returns (bool);
}