// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../access/EducRoles.sol";
import "../interfaces/IEducStudent.sol";

/**
 * @title EducStudent
 * @dev Manages student accounts and their educational achievements with enhanced tracking
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
    
    // Activity tracking by category
    mapping(address => mapping(string => uint256)) public lastActivityByCategory;
    mapping(address => string[]) public studentActivityCategories;

    // Constraints
    uint32 public constant MAX_COURSES_PER_STUDENT = 1000;
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
    
    event StudentActivityCategoryAdded(
        address indexed student,
        string categoryName,
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
        _grantRole(EducRoles.EDUCATOR_ROLE, admin);
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

        // Initialize default activity categories
        _addActivityCategory(student, "Registration");
        _addActivityCategory(student, "CourseCompletion");
        _addActivityCategory(student, "TokenUsage");
        
        // Record first activity
        _recordActivity(student, "Registration", currentTime);

        emit StudentRegistered(student, currentTime);
        emit StudentActivityUpdated(student, "Registration", currentTime);
    }
    
    /**
     * @dev Internal method to add an activity category for a student
     * @param student Address of the student
     * @param category Activity category name
     */
    function _addActivityCategory(address student, string memory category) internal {
        // Check if category already exists
        for (uint256 i = 0; i < studentActivityCategories[student].length; i++) {
            if (keccak256(bytes(studentActivityCategories[student][i])) == keccak256(bytes(category))) {
                return; // Category already exists
            }
        }
        
        studentActivityCategories[student].push(category);
        emit StudentActivityCategoryAdded(student, category, block.timestamp);
    }
    
    /**
     * @dev Internal method to record student activity
     * @param student Address of the student
     * @param category Activity category
     * @param timestamp Time of activity
     */
    function _recordActivity(address student, string memory category, uint256 timestamp) internal {
        // Update general last activity
        students[student].lastActivity = timestamp;
        
        // Update category-specific activity
        lastActivityByCategory[student][category] = timestamp;
        
        emit StudentActivityUpdated(student, category, timestamp);
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
     * @dev Records a course completion with detailed validation and tracking
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
        uint256 currentTime = block.timestamp;
        
        // Record activity
        _recordActivity(student, "CourseCompletion", currentTime);

        // Mark course as completed
        courseCompletions[student][courseId] = true;

        // Store detailed completion record
        bytes32 completionKey = keccak256(abi.encodePacked(student, courseId));
        completionRecords[completionKey] = CourseCompletion({
            student: student,
            courseId: courseId,
            verifiedBy: msg.sender,
            completionTime: currentTime,
            tokensAwarded: tokensAwarded,
            additionalMetadata: keccak256(abi.encodePacked(student, courseId, currentTime))
        });

        emit CourseCompletionRecorded(
            student,
            courseId,
            msg.sender,
            tokensAwarded,
            currentTime
        );
    }
    
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
    )
        external
        onlyRole(EducRoles.ADMIN_ROLE)
        whenNotPaused
        nonReentrant
    {
        require(student != address(0), "EducStudent: Invalid student address");
        require(students[student].studentAddress != address(0), "EducStudent: Student not registered");
        require(tokensUsed > 0, "EducStudent: Invalid token amount");
        require(bytes(purpose).length > 0, "EducStudent: Purpose cannot be empty");
        
        uint256 currentTime = block.timestamp;
        
        // Record activity
        _recordActivity(student, "TokenUsage", currentTime);
        
        emit StudentActivityUpdated(student, 
            string(abi.encodePacked("TokenUsage: ", purpose)), 
            currentTime
        );
    }
    
    /**
     * @dev Adds a custom activity category for a student
     * @param student Address of the student
     * @param category New activity category name
     */
    function addActivityCategory(address student, string calldata category) 
        external
        onlyRole(EducRoles.ADMIN_ROLE)
        whenNotPaused
    {
        require(student != address(0), "EducStudent: Invalid student address");
        require(students[student].studentAddress != address(0), "EducStudent: Student not registered");
        require(bytes(category).length > 0, "EducStudent: Category cannot be empty");
        
        _addActivityCategory(student, category);
    }
    
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
    )
        external
        onlyRole(EducRoles.ADMIN_ROLE)
        whenNotPaused
        nonReentrant
    {
        require(student != address(0), "EducStudent: Invalid student address");
        require(students[student].studentAddress != address(0), "EducStudent: Student not registered");
        require(bytes(category).length > 0, "EducStudent: Category cannot be empty");
        
        bool categoryExists = false;
        for (uint256 i = 0; i < studentActivityCategories[student].length; i++) {
            if (keccak256(bytes(studentActivityCategories[student][i])) == keccak256(bytes(category))) {
                categoryExists = true;
                break;
            }
        }
        
        if (!categoryExists) {
            _addActivityCategory(student, category);
        }
        
        uint256 currentTime = block.timestamp;
        _recordActivity(student, category, currentTime);
        
        emit StudentActivityUpdated(
            student, 
            string(abi.encodePacked(category, ": ", details)), 
            currentTime
        );
    }

    // View functions with enhanced functionality
    
    /**
     * @dev Checks if a student has completed a specific course
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
     * @dev Gets the last activity timestamp for a student in a specific category
     */
    function getStudentLastActivityByCategory(address student, string calldata category)
        external
        view
        returns (uint256)
    {
        return lastActivityByCategory[student][category];
    }
    
    /**
     * @dev Gets all activity categories for a student
     */
    function getStudentActivityCategories(address student)
        external
        view
        returns (string[] memory)
    {
        return studentActivityCategories[student];
    }

    /**
     * @dev Checks if a student is registered
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
     * @dev Checks if a student is considered inactive
     */
    function isStudentInactive(address student)
        external
        view
        returns (bool)
    {
        if (students[student].studentAddress == address(0)) {
            return false; // Not a student
        }
        
        return (block.timestamp - students[student].lastActivity) > STUDENT_INACTIVITY_PERIOD;
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