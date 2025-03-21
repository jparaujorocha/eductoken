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
    // Student structure with enhanced tracking
    struct Student {
        address studentAddress;
        uint256 totalEarned;
        uint32 coursesCompleted;
        uint256 lastActivity;
        uint256 registrationTimestamp;
    }

    // Course completion tracking with detailed metadata
    struct CourseCompletion {
        address student;
        string courseId;
        address verifiedBy;
        uint256 completionTime;
        uint256 tokensAwarded;
        bytes32 additionalMetadata;
    }

    // Mappings for comprehensive tracking
    mapping(address => Student) public students;
    mapping(address => mapping(string => bool)) public courseCompletions;
    mapping(bytes32 => CourseCompletion) public completionRecords;

    // Constraints
    uint32 public constant MAX_COURSES_PER_STUDENT = 100;
    uint256 public constant STUDENT_INACTIVITY_PERIOD = 365 days;

    // Events with enhanced logging
    event StudentRegistered(
        address indexed student,
        uint256 registrationTimestamp
    );

    event CourseCompletionRecorded(
        address indexed student,
        string courseId,
        address indexed educator,
        uint256 tokensAwarded,
        uint256 completionTimestamp
    );

    event StudentActivityUpdated(
        address indexed student,
        string actionType,
        uint256 timestamp
    );

    /**
     * @dev Constructor sets up initial admin role
     * @param admin Address with administrative privileges
     */
    constructor(address admin) {
        require(admin != address(0), "EducStudent: Invalid admin address");
        
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(EducRoles.ADMIN_ROLE, admin);
    }

    /**
     * @dev Internal method to register a new student
     * @param student Address of student to register
     */
    function _registerStudent(address student) internal {
        uint256 currentTime = block.timestamp;

        students[student] = Student({
            studentAddress: student,
            totalEarned: 0,
            coursesCompleted: 0,
            lastActivity: currentTime,
            registrationTimestamp: currentTime
        });

        emit StudentRegistered(student, currentTime);
        emit StudentActivityUpdated(student, "Registration", currentTime);
    }

    /**
     * @dev Registers a new student with comprehensive validation
     * @param student Address of the student to register
     */
    function registerStudent(address student) 
        external 
        override 
        whenNotPaused 
        nonReentrant 
        onlyRole(EducRoles.ADMIN_ROLE)
    {
        require(student != address(0), "EducStudent: Invalid student address");
        require(students[student].studentAddress == address(0), "EducStudent: Student already registered");

        _registerStudent(student);
    }

    /**
     * @dev Records a course completion with detailed validation
     * @param student Address of the student
     * @param courseId Identifier of the completed course
     * @param tokensAwarded Tokens earned for course completion
     */
    function recordCourseCompletion(
        address student,
        string calldata courseId,
        uint256 tokensAwarded
    ) 
        external 
        override 
        onlyRole(EducRoles.EDUCATOR_ROLE)
        whenNotPaused 
        nonReentrant 
    {
        require(student != address(0), "EducStudent: Invalid student address");
        require(bytes(courseId).length > 0, "EducStudent: Invalid course ID");
        require(!courseCompletions[student][courseId], "EducStudent: Course already completed");
        
        // Auto-register student if not exists
        if (students[student].studentAddress == address(0)) {
            _registerStudent(student);
        }

        Student storage studentData = students[student];
        
        require(
            studentData.coursesCompleted < MAX_COURSES_PER_STUDENT, 
            "EducStudent: Maximum courses completed"
        );

        // Update student statistics
        studentData.totalEarned += tokensAwarded;
        studentData.coursesCompleted++;
        studentData.lastActivity = block.timestamp;

        // Mark course as completed
        courseCompletions[student][courseId] = true;

        // Store detailed completion record
        bytes32 completionKey = keccak256(abi.encodePacked(student, courseId));
        completionRecords[completionKey] = CourseCompletion({
            student: student,
            courseId: courseId,
            verifiedBy: msg.sender,
            completionTime: block.timestamp,
            tokensAwarded: tokensAwarded,
            additionalMetadata: keccak256(abi.encodePacked(student, courseId, block.timestamp))
        });

        emit CourseCompletionRecorded(
            student,
            courseId,
            msg.sender,
            tokensAwarded,
            block.timestamp
        );
        emit StudentActivityUpdated(student, "Course Completion", block.timestamp);
    }

    // Existing view functions remain the same as in original implementation
    function hasCourseCompletion(address student, string calldata courseId) 
        external 
        view 
        override 
        returns (bool) 
    {
        return courseCompletions[student][courseId];
    }

    function getStudentTotalEarned(address student) 
        external 
        view 
        override 
        returns (uint256) 
    {
        return students[student].totalEarned;
    }

    function getStudentCoursesCompleted(address student) 
        external 
        view 
        override 
        returns (uint32) 
    {
        return students[student].coursesCompleted;
    }

    function getStudentLastActivity(address student) 
        external 
        view 
        override 
        returns (uint256) 
    {
        return students[student].lastActivity;
    }

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
    function pause() external onlyRole(EducRoles.ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Unpauses student management functions
     */
    function unpause() external onlyRole(EducRoles.ADMIN_ROLE) {
        _unpause();
    }
}