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
 * @dev Manages educational courses and their metadata
 */
contract EducCourse is AccessControl, Pausable, ReentrancyGuard, IEducCourse {
    // Role definitions
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant EDUCATOR_ROLE = keccak256("EDUCATOR_ROLE");

    // Constants
    uint256 public constant MAX_COURSE_ID_LENGTH = 50;
    uint256 public constant MAX_COURSE_NAME_LENGTH = 100;
    uint256 public constant MAX_CHANGE_DESCRIPTION_LENGTH = 200;

    // Course structure
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
    }

    // Course history structure for tracking changes
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

    // Storage
    mapping(bytes32 => Course) public courses;
    mapping(bytes32 => CourseHistory[]) public courseHistories;
    bytes32[] public courseKeys;
    
    // Reference to educator contract
    IEducEducator public educatorContract;

    // Events
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

    /**
     * @dev Constructor that sets up the admin role
     * @param admin The address that will be granted the admin role
     * @param _educatorContract Address of the educator contract
     */
    constructor(address admin, address _educatorContract) {
        require(admin != address(0), "EducCourse: admin cannot be zero address");
        require(_educatorContract != address(0), "EducCourse: educator contract cannot be zero address");

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);

        educatorContract = IEducEducator(_educatorContract);
    }

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
    ) 
        external 
        override 
        whenNotPaused 
        nonReentrant 
    {
        require(educatorContract.isActiveEducator(msg.sender), "EducCourse: caller is not an active educator");
        require(bytes(courseId).length > 0 && bytes(courseId).length <= MAX_COURSE_ID_LENGTH, "EducCourse: invalid course ID length");
        require(bytes(courseName).length > 0 && bytes(courseName).length <= MAX_COURSE_NAME_LENGTH, "EducCourse: invalid course name length");
        require(rewardAmount > 0 && rewardAmount <= educatorContract.getEducatorMintLimit(msg.sender), "EducCourse: invalid reward amount");
        
        bytes32 courseKey = keccak256(abi.encodePacked(msg.sender, courseId));
        require(courses[courseKey].educator == address(0), "EducCourse: course already exists");

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
            version: 1
        });

        courseKeys.push(courseKey);
        
        // Update educator's course count
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
     * @dev Updates an existing course
     * @param courseId ID of the course to update
     * @param courseName Optional new name for the course (empty string to keep current)
     * @param rewardAmount Optional new reward amount (0 to keep current)
     * @param isActive Optional new active status (null to keep current)
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
        require(bytes(changeDescription).length <= MAX_CHANGE_DESCRIPTION_LENGTH, "EducCourse: change description too long");
        
        bytes32 courseKey = keccak256(abi.encodePacked(msg.sender, courseId));
        require(courses[courseKey].educator == msg.sender, "EducCourse: course not found or not owner");
        
        Course storage course = courses[courseKey];
        
        // Store previous values for history
        string memory previousName = course.courseName;
        uint256 previousReward = course.rewardAmount;
        bool previousActive = course.isActive;
        bytes32 previousMetadataHash = course.metadataHash;
        
        // Update course data
        bool updated = false;
        
        if (bytes(courseName).length > 0 && bytes(courseName).length <= MAX_COURSE_NAME_LENGTH) {
            course.courseName = courseName;
            updated = true;
        }
        
        if (rewardAmount > 0 && rewardAmount <= educatorContract.getEducatorMintLimit(msg.sender)) {
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
            
            // Create history record
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
     * @dev Increments the completion count for a course
     * @param educator Address of the course educator
     * @param courseId ID of the completed course
     */
    function incrementCompletionCount(address educator, string calldata courseId) 
        external 
        override 
        onlyRole(ADMIN_ROLE) 
        nonReentrant 
    {
        bytes32 courseKey = keccak256(abi.encodePacked(educator, courseId));
        require(courses[courseKey].educator == educator, "EducCourse: course not found");
        
        courses[courseKey].completionCount++;
    }

    /**
     * @dev Gets course data
     * @param educator Address of the course educator
     * @param courseId ID of the course
     * @return Course data
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
        Course storage course = courses[courseKey];
        require(course.educator != address(0), "EducCourse: course not found");
        
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
     * @return bool True if the course exists and is active
     */
    function isCourseActive(address educator, string calldata courseId) 
        external 
        view 
        override 
        returns (bool) 
    {
        bytes32 courseKey = keccak256(abi.encodePacked(educator, courseId));
        return courses[courseKey].educator != address(0) && courses[courseKey].isActive;
    }

    /**
     * @dev Gets the reward amount for a course
     * @param educator Address of the course educator
     * @param courseId ID of the course
     * @return uint256 The reward amount for the course
     */
    function getCourseReward(address educator, string calldata courseId) 
        external 
        view 
        override 
        returns (uint256) 
    {
        bytes32 courseKey = keccak256(abi.encodePacked(educator, courseId));
        require(courses[courseKey].educator != address(0), "EducCourse: course not found");
        
        return courses[courseKey].rewardAmount;
    }

    /**
     * @dev Gets the total number of courses
     * @return uint256 The total number of courses
     */
    function getTotalCourses() external view override returns (uint256) {
        return courseKeys.length;
    }

    /**
     * @dev Pauses course management functions
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Unpauses course management functions
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
}