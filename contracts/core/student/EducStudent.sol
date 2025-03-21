// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../../access/roles/EducRoles.sol";
import "../../config/constants/SystemConstants.sol";
import "../../interfaces/IEducStudent.sol";
import "./StudentEvents.sol";
import "./types/StudentTypes.sol";

/**
 * @title EducStudent
 * @dev Manages student accounts and their educational achievements with enhanced tracking
 */
contract EducStudent is AccessControl, Pausable, ReentrancyGuard, IEducStudent {
    // Mappings for comprehensive tracking
    mapping(address => StudentTypes.Student) public students;
    mapping(address => mapping(string => bool)) public courseCompletions;
    mapping(bytes32 => StudentTypes.CourseCompletion) public completionRecords;
    
    // Activity tracking by category
    mapping(address => mapping(string => uint256)) public lastActivityByCategory;
    mapping(address => string[]) public studentActivityCategories;

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
     * @dev Registers a new student with structured parameters
     * @param params Registration parameters
     */
    function registerStudent(StudentTypes.StudentRegistrationParams calldata params)
        external
        override
        whenNotPaused
        nonReentrant
        onlyRole(EducRoles.ADMIN_ROLE)
    {
        require(params.studentAddress != address(0), "EducStudent: Invalid student address");
        require(students[params.studentAddress].studentAddress == address(0), "EducStudent: Student already registered");

        _registerStudent(params.studentAddress);
    }

    /**
     * @dev Legacy method for compatibility - registers a new student
     * @param student Address of the student to register
     */
    function registerStudent(address student)
        external
        override
        whenNotPaused
        nonReentrant
        onlyRole(EducRoles.ADMIN_ROLE)
    {
        StudentTypes.StudentRegistrationParams memory params = StudentTypes.StudentRegistrationParams({
            studentAddress: student
        });
        
        require(params.studentAddress != address(0), "EducStudent: Invalid student address");
        require(students[params.studentAddress].studentAddress == address(0), "EducStudent: Student already registered");

        _registerStudent(params.studentAddress);
    }

    /**
     * @dev Records a course completion with structured parameters
     * @param params Course completion parameters
     */
    function recordCourseCompletion(StudentTypes.CourseCompletionParams calldata params)
        external
        override
        onlyRole(EducRoles.EDUCATOR_ROLE)
        whenNotPaused
        nonReentrant
    {
        require(params.studentAddress != address(0), "EducStudent: Invalid student address");
        require(bytes(params.courseId).length > 0, "EducStudent: Invalid course ID");
        require(!courseCompletions[params.studentAddress][params.courseId], "EducStudent: Course already completed");
        
        // Auto-register student if not exists
        if (students[params.studentAddress].studentAddress == address(0)) {
            _registerStudent(params.studentAddress);
        }

        _recordCourseCompletion(params.studentAddress, params.courseId, params.tokensAwarded);
    }

    /**
     * @dev Legacy method for compatibility - records a course completion
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
        onlyRole(EducRoles.EDUCATOR_ROLE)
        whenNotPaused
        nonReentrant
    {
        StudentTypes.CourseCompletionParams memory params = StudentTypes.CourseCompletionParams({
            studentAddress: student,
            courseId: courseId,
            tokensAwarded: tokensAwarded
        });
        
        require(params.studentAddress != address(0), "EducStudent: Invalid student address");
        require(bytes(params.courseId).length > 0, "EducStudent: Invalid course ID");
        require(!courseCompletions[params.studentAddress][params.courseId], "EducStudent: Course already completed");
        
        // Auto-register student if not exists
        if (students[params.studentAddress].studentAddress == address(0)) {
            _registerStudent(params.studentAddress);
        }

        _recordCourseCompletion(params.studentAddress, params.courseId, params.tokensAwarded);
    }
    
    /**
     * @dev Records a student token usage activity with structured parameters
     * @param params Token usage parameters
     */
    function recordTokenUsage(StudentTypes.TokenUsageParams calldata params)
        external
        override
        onlyRole(EducRoles.ADMIN_ROLE)
        whenNotPaused
        nonReentrant
    {
        require(params.studentAddress != address(0), "EducStudent: Invalid student address");
        require(students[params.studentAddress].studentAddress != address(0), "EducStudent: Student not registered");
        require(params.tokensUsed > 0, "EducStudent: Invalid token amount");
        require(bytes(params.purpose).length > 0, "EducStudent: Purpose cannot be empty");
        
        _recordTokenUsage(params.studentAddress, params.tokensUsed, params.purpose);
    }
    
    /**
     * @dev Legacy method for compatibility - records token usage
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
        override
        onlyRole(EducRoles.ADMIN_ROLE)
        whenNotPaused
        nonReentrant
    {
        StudentTypes.TokenUsageParams memory params = StudentTypes.TokenUsageParams({
            studentAddress: student,
            tokensUsed: tokensUsed,
            purpose: purpose
        });
        
        require(params.studentAddress != address(0), "EducStudent: Invalid student address");
        require(students[params.studentAddress].studentAddress != address(0), "EducStudent: Student not registered");
        require(params.tokensUsed > 0, "EducStudent: Invalid token amount");
        require(bytes(params.purpose).length > 0, "EducStudent: Purpose cannot be empty");
        
        _recordTokenUsage(params.studentAddress, params.tokensUsed, params.purpose);
    }
    
    /**
     * @dev Adds a custom activity category for a student
     * @param student Address of the student
     * @param category New activity category name
     */
    function addActivityCategory(address student, string calldata category)
        external
        override
        onlyRole(EducRoles.ADMIN_ROLE)
        whenNotPaused
    {
        require(student != address(0), "EducStudent: Invalid student address");
        require(students[student].studentAddress != address(0), "EducStudent: Student not registered");
        require(bytes(category).length > 0, "EducStudent: Category cannot be empty");
        
        _addActivityCategory(student, category);
    }
    
    /**
     * @dev Records a custom activity for a student with structured parameters
     * @param params Custom activity parameters
     */
    function recordCustomActivity(StudentTypes.CustomActivityParams calldata params)
        external
        override
        onlyRole(EducRoles.ADMIN_ROLE)
        whenNotPaused
        nonReentrant
    {
        require(params.studentAddress != address(0), "EducStudent: Invalid student address");
        require(students[params.studentAddress].studentAddress != address(0), "EducStudent: Student not registered");
        require(bytes(params.category).length > 0, "EducStudent: Category cannot be empty");
        
        _recordCustomActivity(params.studentAddress, params.category, params.details);
    }
    
    /**
     * @dev Legacy method for compatibility - records a custom activity
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
        override
        onlyRole(EducRoles.ADMIN_ROLE)
        whenNotPaused
        nonReentrant
    {
        StudentTypes.CustomActivityParams memory params = StudentTypes.CustomActivityParams({
            studentAddress: student,
            category: category,
            details: details
        });
        
        require(params.studentAddress != address(0), "EducStudent: Invalid student address");
        require(students[params.studentAddress].studentAddress != address(0), "EducStudent: Student not registered");
        require(bytes(params.category).length > 0, "EducStudent: Category cannot be empty");
        
        _recordCustomActivity(params.studentAddress, params.category, params.details);
    }

    /**
     * @dev Checks if a student has completed a specific course
     * @param student Address of the student
     * @param courseId ID of the course to check
     * @return completed True if the student has completed the course
     */
    function hasCourseCompletion(address student, string calldata courseId)
        external
        view
        override
        returns (bool completed)
    {
        return courseCompletions[student][courseId];
    }

    /**
     * @dev Gets a student's total earned tokens
     * @param student Address of the student
     * @return totalEarned The total tokens earned by the student
     */
    function getStudentTotalEarned(address student)
        external
        view
        override
        returns (uint256 totalEarned)
    {
        return students[student].totalEarned;
    }

    /**
     * @dev Gets the number of courses completed by a student
     * @param student Address of the student
     * @return coursesCompleted The number of courses completed
     */
    function getStudentCoursesCompleted(address student)
        external
        view
        override
        returns (uint32 coursesCompleted)
    {
        return students[student].coursesCompleted;
    }

    /**
     * @dev Gets the last activity timestamp for a student
     * @param student Address of the student
     * @return lastActivity The timestamp of the student's last activity
     */
    function getStudentLastActivity(address student)
        external
        view
        override
        returns (uint256 lastActivity)
    {
        return students[student].lastActivity;
    }
    
    /**
     * @dev Gets the last activity timestamp for a student in a specific category
     * @param student Address of the student
     * @param category Activity category
     * @return lastActivity The timestamp of the last activity in the category
     */
    function getStudentLastActivityByCategory(address student, string calldata category)
        external
        view
        override
        returns (uint256 lastActivity)
    {
        return lastActivityByCategory[student][category];
    }
    
    /**
     * @dev Gets all activity categories for a student
     * @param student Address of the student
     * @return categories Array of activity category names
     */
    function getStudentActivityCategories(address student)
        external
        view
        override
        returns (string[] memory categories)
    {
        return studentActivityCategories[student];
    }

    /**
     * @dev Checks if a student is registered
     * @param student Address to check
     * @return isRegistered True if the address is a registered student
     */
    function isStudent(address student)
        external
        view
        override
        returns (bool isRegistered)
    {
        return students[student].studentAddress != address(0);
    }
    
    /**
     * @dev Checks if a student is considered inactive
     * @param student Address of the student
     * @return isInactive True if the student is inactive
     */
    function isStudentInactive(address student)
        external
        view
        override
        returns (bool isInactive)
    {
        if (students[student].studentAddress == address(0)) {
            return false; // Not a student
        }
        
        return (block.timestamp - students[student].lastActivity) > SystemConstants.STUDENT_INACTIVITY_PERIOD;
    }
    
    /**
     * @dev Gets all information about a student
     * @param student Address of the student
     * @return studentInfo The student's data structure
     */
    function getStudentInfo(address student)
        external
        view
        override
        returns (StudentTypes.Student memory studentInfo)
    {
        return students[student];
    }
    
    /**
     * @dev Gets detailed information about a course completion
     * @param student Address of the student
     * @param courseId ID of the completed course
     * @return completion The course completion data structure
     */
    function getCourseCompletionInfo(address student, string calldata courseId)
        external
        view
        override
        returns (StudentTypes.CourseCompletion memory completion)
    {
        bytes32 completionKey = keccak256(abi.encodePacked(student, courseId));
        return completionRecords[completionKey];
    }
    
    /**
     * @dev Internal method to register a new student
     * @param student Address of student to register
     */
    function _registerStudent(address student) private {
        uint256 currentTime = block.timestamp;

        students[student] = StudentTypes.Student({
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

        emit StudentEvents.StudentRegistered(student, currentTime);
        emit StudentEvents.StudentActivityUpdated(student, "Registration", currentTime);
    }
    
    /**
     * @dev Internal method to record a course completion
     * @param student Address of the student
     * @param courseId ID of the completed course
     * @param tokensAwarded Amount of tokens awarded
     */
    function _recordCourseCompletion(
        address student,
        string memory courseId,
        uint256 tokensAwarded
    ) private {
        StudentTypes.Student storage studentData = students[student];
        
        require(
            studentData.coursesCompleted < SystemConstants.MAX_COURSES_PER_STUDENT, 
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
        completionRecords[completionKey] = StudentTypes.CourseCompletion({
            student: student,
            courseId: courseId,
            verifiedBy: msg.sender,
            completionTime: currentTime,
            tokensAwarded: tokensAwarded,
            additionalMetadata: keccak256(abi.encodePacked(student, courseId, currentTime))
        });

        emit StudentEvents.CourseCompletionRecorded(
            student,
            courseId,
            msg.sender,
            tokensAwarded,
            currentTime
        );
    }
    
    /**
     * @dev Internal method to record token usage
     * @param student Address of the student
     * @param tokensUsed Amount of tokens used
     * @param purpose Purpose of token usage
     */
    function _recordTokenUsage(
        address student,
        uint256 tokensUsed,
        string memory purpose
    ) private {
        uint256 currentTime = block.timestamp;
        
        // Record activity
        _recordActivity(student, "TokenUsage", currentTime);
        
        emit StudentEvents.StudentTokensUsed(
            student,
            tokensUsed,
            purpose,
            currentTime
        );
        
        emit StudentEvents.StudentActivityUpdated(
            student, 
            string(abi.encodePacked("TokenUsage: ", purpose)), 
            currentTime
        );
    }
    
    /**
     * @dev Internal method to add an activity category for a student
     * @param student Address of the student
     * @param category Activity category name
     */
    function _addActivityCategory(address student, string memory category) private {
        // Check if category already exists
        for (uint256 i = 0; i < studentActivityCategories[student].length; i++) {
            if (keccak256(bytes(studentActivityCategories[student][i])) == keccak256(bytes(category))) {
                return; // Category already exists
            }
        }
        
        studentActivityCategories[student].push(category);
        emit StudentEvents.StudentActivityCategoryAdded(student, category, block.timestamp);
    }
    
    /**
     * @dev Internal method to record a custom activity
     * @param student Address of the student
     * @param category Activity category
     * @param details Activity details
     */
    function _recordCustomActivity(
        address student,
        string memory category,
        string memory details
    ) private {
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
        
        emit StudentEvents.StudentActivityUpdated(
            student, 
            string(abi.encodePacked(category, ": ", details)), 
            currentTime
        );
    }
    
    /**
     * @dev Internal method to record student activity
     * @param student Address of the student
     * @param category Activity category
     * @param timestamp Time of activity
     */
    function _recordActivity(address student, string memory category, uint256 timestamp) private {
        // Update general last activity
        students[student].lastActivity = timestamp;
        
        // Update category-specific activity
        lastActivityByCategory[student][category] = timestamp;
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