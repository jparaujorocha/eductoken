// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../access/EducRoles.sol";
import "../interfaces/IEducCourse.sol";
import "../interfaces/IEducEducator.sol";

/**
 * @title EducCourse
 * @dev Advanced course management with enhanced tracking and governance
 */
contract EducCourse is AccessControl, Pausable, ReentrancyGuard, IEducCourse {
    // Course structure with comprehensive metadata
    struct Course {
        string courseId;
        string courseName;
        address educator;
        uint256 rewardAmount;
        uint32 completionCount;
        bool isActive;
        bytes32 metadataHash;
        uint256 createdAt;
        uint256 lastUpdatedAt;
        uint32 version;
        uint256 lastCompletionTimestamp;
    }

    // Course version history tracking
    struct CourseHistory {
        string courseId;
        address educator;
        uint32 version;
        string previousName;
        uint256 previousReward;
        bool previousActive;
        bytes32 previousMetadataHash;
        address updatedBy;
        uint256 updatedAt;
        string changeDescription;
    }

    // Storage mappings with enhanced tracking
    mapping(bytes32 => Course) public courses;
    mapping(bytes32 => CourseHistory[]) public courseHistories;
    bytes32[] public courseKeys;
    
    // Reference to educator contract
    IEducEducator public educatorContract;

    // Constraints
    uint256 public constant MAX_COURSE_ID_LENGTH = 50;
    uint256 public constant MAX_COURSE_NAME_LENGTH = 100;
    uint256 public constant MAX_CHANGE_DESCRIPTION_LENGTH = 200;
    uint256 public constant MAX_COURSES_PER_EDUCATOR = 100;

    // Events with detailed logging
    event CourseCreated(
        string courseId,
        string courseName,
        address indexed educator,
        uint256 rewardAmount,
        uint256 timestamp
    );

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

    event CourseCompletionTracked(
        string courseId,
        address indexed educator,
        uint32 completionCount,
        uint256 timestamp
    );

    /**
     * @dev Constructor sets up admin and educator contract reference
     * @param admin Administrator address
     * @param _educatorContract Educator management contract
     */
    constructor(address admin, address _educatorContract) {
        require(admin != address(0), "EducCourse: Invalid admin address");
        require(_educatorContract != address(0), "EducCourse: Invalid educator contract");

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(EducRoles.ADMIN_ROLE, admin);

        educatorContract = IEducEducator(_educatorContract);
    }

    /**
     * @dev Creates a new course with comprehensive validation
     */
    function createCourse(
        string calldata courseId,
        string calldata courseName,
        uint256 rewardAmount,
        bytes32 metadataHash
    ) 
        external 
        override 
        whenNotPaused 
        nonReentrant 
    {
        require(educatorContract.isActiveEducator(msg.sender), "EducCourse: Caller not an active educator");
        require(bytes(courseId).length > 0 && bytes(courseId).length <= MAX_COURSE_ID_LENGTH, "EducCourse: Invalid course ID");
        require(bytes(courseName).length > 0 && bytes(courseName).length <= MAX_COURSE_NAME_LENGTH, "EducCourse: Invalid course name");
        require(rewardAmount > 0, "EducCourse: Invalid reward amount");
        
        bytes32 courseKey = keccak256(abi.encodePacked(msg.sender, courseId));
        require(courses[courseKey].educator == address(0), "EducCourse: Course already exists");

        uint256 currentTime = block.timestamp;

        courses[courseKey] = Course({
            courseId: courseId,
            courseName: courseName,
            educator: msg.sender,
            rewardAmount: rewardAmount,
            completionCount: 0,
            isActive: true,
            metadataHash: metadataHash,
            createdAt: currentTime,
            lastUpdatedAt: currentTime,
            version: 1,
            lastCompletionTimestamp: 0
        });

        courseKeys.push(courseKey);
        
        educatorContract.incrementCourseCount(msg.sender);

        emit CourseCreated(
            courseId,
            courseName,
            msg.sender,
            rewardAmount,
            currentTime
        );
    }

    /**
     * @dev Updates an existing course with comprehensive change tracking
     */
    function updateCourse(
        string calldata courseId,
        string calldata courseName,
        uint256 rewardAmount,
        bool isActive,
        bytes32 metadataHash,
        string calldata changeDescription
    ) 
        external 
        override 
        whenNotPaused 
        nonReentrant 
    {
        require(bytes(changeDescription).length <= MAX_CHANGE_DESCRIPTION_LENGTH, "EducCourse: Change description too long");
        
        bytes32 courseKey = keccak256(abi.encodePacked(msg.sender, courseId));
        require(courses[courseKey].educator == msg.sender, "EducCourse: Course not found or not owner");
        
        Course storage course = courses[courseKey];
        
        // Store previous values for history tracking
        string memory previousName = course.courseName;
        uint256 previousReward = course.rewardAmount;
        bool previousActive = course.isActive;
        bytes32 previousMetadataHash = course.metadataHash;
        
        bool updated = false;
        
        if (bytes(courseName).length > 0 && bytes(courseName).length <= MAX_COURSE_NAME_LENGTH) {
            course.courseName = courseName;
            updated = true;
        }
        
        if (rewardAmount > 0) {
            course.rewardAmount = rewardAmount;
            updated = true;
        }
        
        course.isActive = isActive;
        
        if (metadataHash != bytes32(0)) {
            course.metadataHash = metadataHash;
            updated = true;
        }
        
        if (updated) {
            uint256 currentTime = block.timestamp;
            course.lastUpdatedAt = currentTime;
            course.version++;
            
            CourseHistory memory history = CourseHistory({
                courseId: courseId,
                educator: msg.sender,
                version: course.version,
                previousName: previousName,
                previousReward: previousReward,
                previousActive: previousActive,
                previousMetadataHash: previousMetadataHash,
                updatedBy: msg.sender,
                updatedAt: currentTime,
                changeDescription: changeDescription
            });
            
            courseHistories[courseKey].push(history);
            
            emit CourseUpdated(
                courseId,
                msg.sender,
                course.version,
                previousName,
                course.courseName,
                previousReward,
                course.rewardAmount,
                previousActive,
                course.isActive,
                msg.sender,
                currentTime
            );
        }
    }

    /**
     * @dev Increments course completion count with detailed tracking
     */
    function incrementCompletionCount(address educator, string calldata courseId) 
        external 
        override 
        onlyRole(EducRoles.ADMIN_ROLE) 
        nonReentrant 
    {
        bytes32 courseKey = keccak256(abi.encodePacked(educator, courseId));
        require(courses[courseKey].educator == educator, "EducCourse: Course not found");
        
        Course storage courseData = courses[courseKey];
        courseData.completionCount++;
        courseData.lastCompletionTimestamp = block.timestamp;

        emit CourseCompletionTracked(
            courseId, 
            educator, 
            courseData.completionCount, 
            block.timestamp
        );
    }

    // Existing view functions remain similar to original implementation
    function getCourse(address educator, string calldata courseId) 
        external 
        view 
        override 
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
        ) 
    {
        bytes32 courseKey = keccak256(abi.encodePacked(educator, courseId));
        Course storage course = courses[courseKey];
        require(course.educator != address(0), "EducCourse: Course not found");
        
        return (
            course.courseId,
            course.courseName,
            course.educator,
            course.rewardAmount,
            course.completionCount,
            course.isActive,
            course.metadataHash,
            course.createdAt,
            course.lastUpdatedAt,
            course.version
        );
    }

    function isCourseActive(address educator, string calldata courseId) 
        external 
        view 
        override 
        returns (bool) 
    {
        bytes32 courseKey = keccak256(abi.encodePacked(educator, courseId));
        return courses[courseKey].educator != address(0) && courses[courseKey].isActive;
    }

    function getCourseReward(address educator, string calldata courseId) 
        external 
        view 
        override 
        returns (uint256) 
    {
        bytes32 courseKey = keccak256(abi.encodePacked(educator, courseId));
        require(courses[courseKey].educator != address(0), "EducCourse: Course not found");
        
        return courses[courseKey].rewardAmount;
    }

    function getTotalCourses() external view override returns (uint256) {
        return courseKeys.length;
    }

    /**
     * @dev Pauses course management functions
     */
    function pause() external onlyRole(EducRoles.ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Unpauses course management functions
     */
    function unpause() external onlyRole(EducRoles.ADMIN_ROLE) {
        _unpause();
    }
}