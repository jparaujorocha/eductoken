// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../../access/roles/EducRoles.sol";
import "../../config/constants/SystemConstants.sol";
import "../../interfaces/IEducCourse.sol";
import "../../interfaces/IEducEducator.sol";
import "./CourseEvents.sol";
import "./types/CourseTypes.sol";

/**
 * @title EducCourse
 * @dev Advanced course management with enhanced tracking and governance
 */
contract EducCourse is AccessControl, Pausable, ReentrancyGuard, IEducCourse {
    // Storage mappings with enhanced tracking
    mapping(bytes32 => CourseTypes.Course) public courses;
    mapping(bytes32 => CourseTypes.CourseHistory[]) public courseHistories;
    bytes32[] public courseKeys;
    
    // Reference to educator contract
    IEducEducator public educatorContract;

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
     * @dev Creates a new course with structured parameters
     * @param params Course creation parameters
     */
    function createCourse(CourseTypes.CourseCreationParams calldata params) 
        external
        override 
        whenNotPaused 
        nonReentrant 
    {
        _validateCourseCreation(params);
        _createCourse(params);
    }
    
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
    )
        external
        override
        whenNotPaused
        nonReentrant
    {
        CourseTypes.CourseCreationParams memory params = CourseTypes.CourseCreationParams({
            courseId: courseId,
            courseName: courseName,
            rewardAmount: rewardAmount,
            metadataHash: metadataHash
        });
        
        _validateCourseCreation(params);
        _createCourse(params);
    }
    
    /**
     * @dev Validates course creation parameters
     * @param params Course creation parameters to validate
     */
    function _validateCourseCreation(CourseTypes.CourseCreationParams memory params) private view {
        require(educatorContract.isActiveEducator(msg.sender), "EducCourse: Caller not an active educator");
        require(bytes(params.courseId).length > 0 && bytes(params.courseId).length <= SystemConstants.MAX_COURSE_ID_LENGTH, 
            "EducCourse: Invalid course ID");
        require(bytes(params.courseName).length > 0 && bytes(params.courseName).length <= SystemConstants.MAX_COURSE_NAME_LENGTH, 
            "EducCourse: Invalid course name");
        require(params.rewardAmount > 0, "EducCourse: Invalid reward amount");
        
        bytes32 courseKey = keccak256(abi.encodePacked(msg.sender, params.courseId));
        require(courses[courseKey].educator == address(0), "EducCourse: Course already exists");
    }
    
    /**
     * @dev Internal implementation of course creation
     * @param params Course creation parameters
     */
    function _createCourse(CourseTypes.CourseCreationParams memory params) private {
        bytes32 courseKey = keccak256(abi.encodePacked(msg.sender, params.courseId));
        uint256 currentTime = block.timestamp;

        CourseTypes.Course memory newCourse = CourseTypes.Course({
            courseId: params.courseId,
            courseName: params.courseName,
            educator: msg.sender,
            rewardAmount: params.rewardAmount,
            completionCount: 0,
            isActive: true,
            metadataHash: params.metadataHash,
            createdAt: currentTime,
            lastUpdatedAt: currentTime,
            lastCompletionTimestamp: 0,
            version: 1
        });
        
        courses[courseKey] = newCourse;
        courseKeys.push(courseKey);
        
        educatorContract.incrementCourseCount(msg.sender);

        emit CourseEvents.CourseCreated(
            params.courseId,
            params.courseName,
            msg.sender,
            params.rewardAmount,
            currentTime
        );
    }

    /**
     * @dev Updates an existing course with structured parameters
     * @param params Course update parameters
     */
    function updateCourse(CourseTypes.CourseUpdateParams calldata params) 
        external 
        override 
        whenNotPaused 
        nonReentrant 
    {
        _validateCourseUpdate(params);
        _updateCourse(params);
    }
    
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
    ) 
        external 
        override 
        whenNotPaused 
        nonReentrant 
    {
        CourseTypes.CourseUpdateParams memory params = CourseTypes.CourseUpdateParams({
            courseId: courseId,
            courseName: courseName,
            rewardAmount: rewardAmount,
            isActive: isActive,
            metadataHash: metadataHash,
            changeDescription: changeDescription
        });
        
        _validateCourseUpdate(params);
        _updateCourse(params);
    }
    
    /**
     * @dev Validates course update parameters
     * @param params Course update parameters to validate
     */
    function _validateCourseUpdate(CourseTypes.CourseUpdateParams memory params) private view {
        require(bytes(params.changeDescription).length <= SystemConstants.MAX_CHANGE_DESCRIPTION_LENGTH, 
            "EducCourse: Change description too long");
        
        bytes32 courseKey = keccak256(abi.encodePacked(msg.sender, params.courseId));
        require(courses[courseKey].educator == msg.sender, "EducCourse: Course not found or not owner");
    }
    
    /**
     * @dev Internal implementation of course update
     * @param params Course update parameters
     */
    function _updateCourse(CourseTypes.CourseUpdateParams memory params) private {
        bytes32 courseKey = keccak256(abi.encodePacked(msg.sender, params.courseId));
        CourseTypes.Course storage course = courses[courseKey];
        
        // Store previous values for history tracking
        string memory previousName = course.courseName;
        uint256 previousReward = course.rewardAmount;
        bool previousActive = course.isActive;
        bytes32 previousMetadataHash = course.metadataHash;
        
        bool updated = false;
        
        if (bytes(params.courseName).length > 0 && bytes(params.courseName).length <= SystemConstants.MAX_COURSE_NAME_LENGTH) {
            course.courseName = params.courseName;
            updated = true;
        }
        
        if (params.rewardAmount > 0) {
            course.rewardAmount = params.rewardAmount;
            updated = true;
        }
        
        course.isActive = params.isActive;
        
        if (params.metadataHash != bytes32(0)) {
            course.metadataHash = params.metadataHash;
            updated = true;
        }
        
        if (updated || previousActive != params.isActive) {
            uint256 currentTime = block.timestamp;
            course.lastUpdatedAt = currentTime;
            course.version++;
            
            CourseTypes.CourseHistory memory history = CourseTypes.CourseHistory({
                courseId: params.courseId,
                educator: msg.sender,
                version: course.version,
                previousName: previousName,
                previousReward: previousReward,
                previousActive: previousActive,
                previousMetadataHash: previousMetadataHash,
                updatedBy: msg.sender,
                updatedAt: currentTime,
                changeDescription: params.changeDescription
            });
            
            courseHistories[courseKey].push(history);
            
            emit CourseEvents.CourseUpdated(
                params.courseId,
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
     * @param educator Address of the course educator
     * @param courseId ID of the completed course
     */
    function incrementCompletionCount(address educator, string calldata courseId) 
        external 
        override 
        onlyRole(EducRoles.ADMIN_ROLE) 
        nonReentrant 
    {
        bytes32 courseKey = keccak256(abi.encodePacked(educator, courseId));
        require(courses[courseKey].educator == educator, "EducCourse: Course not found");
        
        CourseTypes.Course storage courseData = courses[courseKey];
        courseData.completionCount++;
        courseData.lastCompletionTimestamp = block.timestamp;

        emit CourseEvents.CourseCompletionTracked(
            courseId, 
            educator, 
            courseData.completionCount, 
            block.timestamp
        );
    }

    /**
     * @dev Gets course data as a structured object
     * @param educator Address of the course educator
     * @param courseId ID of the course
     * @return course The course data
     */
    function getCourseInfo(address educator, string calldata courseId)
        external
        view
        override
        returns (CourseTypes.Course memory course)
    {
        bytes32 courseKey = keccak256(abi.encodePacked(educator, courseId));
        require(courses[courseKey].educator != address(0), "EducCourse: Course not found");
        
        return courses[courseKey];
    }

    /**
     * @dev Legacy method for compatibility - gets course data
     * @param educator Address of the course educator
     * @param courseId ID of the course
     */
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
        CourseTypes.Course storage course = courses[courseKey];
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

    /**
     * @dev Checks if a course exists and is active
     * @param educator Address of the course educator
     * @param courseId ID of the course
     * @return active True if the course exists and is active
     */
    function isCourseActive(address educator, string calldata courseId) 
        external 
        view 
        override 
        returns (bool active) 
    {
        bytes32 courseKey = keccak256(abi.encodePacked(educator, courseId));
        return courses[courseKey].educator != address(0) && courses[courseKey].isActive;
    }

    /**
     * @dev Gets the reward amount for a course
     * @param educator Address of the course educator
     * @param courseId ID of the course
     * @return reward The reward amount for the course
     */
    function getCourseReward(address educator, string calldata courseId) 
        external 
        view 
        override 
        returns (uint256 reward) 
    {
        bytes32 courseKey = keccak256(abi.encodePacked(educator, courseId));
        require(courses[courseKey].educator != address(0), "EducCourse: Course not found");
        
        return courses[courseKey].rewardAmount;
    }

    /**
     * @dev Gets the total number of courses
     * @return total The total number of courses
     */
    function getTotalCourses() 
        external 
        view 
        override 
        returns (uint256 total) 
    {
        return courseKeys.length;
    }
    
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
        override
        returns (CourseTypes.CourseHistory memory history)
    {
        bytes32 courseKey = keccak256(abi.encodePacked(educator, courseId));
        require(courses[courseKey].educator != address(0), "EducCourse: Course not found");
        
        CourseTypes.CourseHistory[] storage histories = courseHistories[courseKey];
        
        for (uint256 i = 0; i < histories.length; i++) {
            if (histories[i].version == version) {
                return histories[i];
            }
        }
        
        revert("EducCourse: History version not found");
    }
    
    /**
     * @dev Gets the number of history entries for a course
     * @param educator Address of the course educator
     * @param courseId ID of the course
     * @return count The number of history entries
     */
    function getCourseHistoryCount(address educator, string calldata courseId)
        external
        view
        override
        returns (uint256 count)
    {
        bytes32 courseKey = keccak256(abi.encodePacked(educator, courseId));
        require(courses[courseKey].educator != address(0), "EducCourse: Course not found");
        
        return courseHistories[courseKey].length;
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