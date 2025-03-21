// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../access/EducRoles.sol";
import "../interfaces/IEducStudent.sol";

/**
 * @title EducStudent
 * @dev Manages student accounts and their educational achievements
 */
contract EducStudent is AccessControl, Pausable, ReentrancyGuard, IEducStudent {
    // Role definitions
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant EDUCATOR_ROLE = keccak256("EDUCATOR_ROLE");

    // Student structure
    struct Student {
        address studentAddress;
        uint256 totalEarned;
        uint32 coursesCompleted;
        uint256 lastActivity;
    }

    // Course completion structure
    struct CourseCompletion {
        address student;
        string courseId;
        address verifiedBy;
        uint256 completionTime;
        uint256 tokensAwarded;
    }

    // Storage
    mapping(address => Student) public students;
    mapping(address => mapping(string => bool)) public courseCompletions;
    mapping(bytes32 => CourseCompletion) public completionRecords;

    // Events
    event StudentRegistered(
        address indexed student,
        uint256 timestamp
    );

    event CourseCompleted(
        address indexed student,
        string courseId,
        address indexed educator,
        uint256 tokensAwarded,
        uint256 timestamp
    );

    /**
     * @dev Constructor that sets up the admin role
     * @param admin The address that will be granted the admin role
     */
    constructor(address admin) {
        require(admin != address(0), "EducStudent: admin cannot be zero address");

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
    }

    /**
     * @dev Registers a new student
     * @param student Address of the student to register
     */
    function registerStudent(address student) 
        external 
        override 
        whenNotPaused 
        nonReentrant 
    {
        require(student != address(0), "EducStudent: student cannot be zero address");
        require(students[student].studentAddress == address(0), "EducStudent: student already registered");

        uint256 currentTime = block.timestamp;

        students[student] = Student({
            studentAddress: student,
            totalEarned: 0,
            coursesCompleted: 0,
            lastActivity: currentTime
        });

        emit StudentRegistered(student, currentTime);
    }

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
    ) 
        external 
        override 
        onlyRole(EDUCATOR_ROLE) 
        whenNotPaused 
        nonReentrant 
    {
        require(student != address(0), "EducStudent: student cannot be zero address");
        require(bytes(courseId).length > 0, "EducStudent: courseId cannot be empty");
        require(!courseCompletions[student][courseId], "EducStudent: course already completed");
        
        // Ensure student exists or register them
        if (students[student].studentAddress == address(0)) {
            students[student] = Student({
                studentAddress: student,
                totalEarned: 0,
                coursesCompleted: 0,
                lastActivity: block.timestamp
            });
        }

        // Update student statistics
        Student storage studentData = students[student];
        studentData.totalEarned += tokensAwarded;
        studentData.coursesCompleted += 1;
        studentData.lastActivity = block.timestamp;

        // Mark course as completed
        courseCompletions[student][courseId] = true;

        // Store completion record
        bytes32 completionKey = keccak256(abi.encodePacked(student, courseId));
        completionRecords[completionKey] = CourseCompletion({
            student: student,
            courseId: courseId,
            verifiedBy: msg.sender,
            completionTime: block.timestamp,
            tokensAwarded: tokensAwarded
        });

        emit CourseCompleted(
            student,
            courseId,
            msg.sender,
            tokensAwarded,
            block.timestamp
        );
    }

    /**
     * @dev Checks if a student has completed a specific course
     * @param student Address of the student
     * @param courseId ID of the course to check
     * @return bool True if the student has completed the course
     */
    function hasCourseCompletion(address student, string calldata courseId) 
        external 
        view 
        override 
        returns (bool) 
    {
        return courseCompletions[student][courseId];
    }

    /**
     * @dev Gets a student's total earned tokens
     * @param student Address of the student
     * @return uint256 The total tokens earned by the student
     */
    function getStudentTotalEarned(address student) 
        external 
        view 
        override 
        returns (uint256) 
    {
        return students[student].totalEarned;
    }

    /**
     * @dev Gets the number of courses completed by a student
     * @param student Address of the student
     * @return uint32 The number of courses completed
     */
    function getStudentCoursesCompleted(address student) 
        external 
        view 
        override 
        returns (uint32) 
    {
        return students[student].coursesCompleted;
    }

    /**
     * @dev Gets the last activity timestamp for a student
     * @param student Address of the student
     * @return uint256 The timestamp of the student's last activity
     */
    function getStudentLastActivity(address student) 
        external 
        view 
        override 
        returns (uint256) 
    {
        return students[student].lastActivity;
    }

    /**
     * @dev Checks if a student is registered
     * @param student Address to check
     * @return bool True if the address is a registered student
     */
    function isStudent(address student) 
        external 
        view 
        override 
        returns (bool) 
    {
        return students[student].studentAddress != address(0);
    }

    /**
     * @dev Pauses student management functions
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Unpauses student management functions
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
}