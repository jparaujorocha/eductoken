// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./core/EducToken.sol";
import "./core/EducEducator.sol";
import "./core/EducStudent.sol";
import "./core/EducCourse.sol";
import "./config/EducConfig.sol";
import "./security/EducPause.sol";
import "./governance/EducMultisig.sol";
import "./governance/EducProposal.sol";
import "./access/EducRoles.sol";

/**
 * @title EducLearning
 * @dev Main contract that integrates all components of the EducLearning system
 */
contract EducLearning is AccessControl, Pausable, ReentrancyGuard, Initializable {
    // References to other contracts
    EducToken public token;
    EducEducator public educator;
    EducStudent public student;
    EducCourse public course;
    EducConfig public config;
    EducPause public pauseControl;
    EducMultisig public multisig;
    EducProposal public proposal;

    // Events
    event ContractsInitialized(
        address token,
        address educator,
        address student,
        address course,
        address config,
        address pauseControl,
        address multisig,
        address proposal,
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
     * @dev Constructor
     * @param admin The address that will be granted the admin role
     */
    constructor(address admin) {
        require(admin != address(0), "EducLearning: admin cannot be zero address");

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(EducRoles.ADMIN_ROLE, admin);
        _grantRole(EducRoles.PAUSER_ROLE, admin);
        _grantRole(EducRoles.UPGRADER_ROLE, admin);
    }

    /**
     * @dev Initializes the system with contract addresses
     * @param _token Token contract address
     * @param _educator Educator contract address
     * @param _student Student contract address
     * @param _course Course contract address
     * @param _config Configuration contract address
     * @param _pauseControl Pause control contract address
     * @param _multisig Multisig contract address
     * @param _proposal Proposal contract address
     */
    function initialize(
        address _token,
        address _educator,
        address _student,
        address _course,
        address _config,
        address _pauseControl,
        address _multisig,
        address _proposal
    ) 
        external 
        initializer 
        onlyRole(EducRoles.ADMIN_ROLE) 
    {
        require(_token != address(0), "EducLearning: token address cannot be zero");
        require(_educator != address(0), "EducLearning: educator address cannot be zero");
        require(_student != address(0), "EducLearning: student address cannot be zero");
        require(_course != address(0), "EducLearning: course address cannot be zero");
        require(_config != address(0), "EducLearning: config address cannot be zero");
        require(_pauseControl != address(0), "EducLearning: pause control address cannot be zero");
        require(_multisig != address(0), "EducLearning: multisig address cannot be zero");
        require(_proposal != address(0), "EducLearning: proposal address cannot be zero");

        token = EducToken(_token);
        educator = EducEducator(_educator);
        student = EducStudent(_student);
        course = EducCourse(_course);
        config = EducConfig(_config);
        pauseControl = EducPause(_pauseControl);
        multisig = EducMultisig(_multisig);
        proposal = EducProposal(_proposal);

        emit ContractsInitialized(
            _token,
            _educator,
            _student,
            _course,
            _config,
            _pauseControl,
            _multisig,
            _proposal,
            block.timestamp
        );
    }

    /**
     * @dev Completes a course for a student and mints reward tokens
     * @param studentAddress Address of the student completing the course
     * @param courseId ID of the completed course
     */
    function completeCourse(
        address studentAddress,
        string calldata courseId
    ) 
        external 
        whenNotPaused 
        nonReentrant 
    {
        // Verify educator is active
        require(educator.isActiveEducator(msg.sender), "EducLearning: caller is not an active educator");
        
        // Verify course exists and is active
        require(course.isCourseActive(msg.sender, courseId), "EducLearning: course not found or inactive");
        
        // Verify course is not already completed by the student
        require(!student.hasCourseCompletion(studentAddress, courseId), "EducLearning: course already completed");
        
        // Get course reward amount
        uint256 rewardAmount = course.getCourseReward(msg.sender, courseId);
        
        // Record course completion in student contract
        student.recordCourseCompletion(studentAddress, courseId, rewardAmount);
        
        // Increment course completion count
        course.incrementCompletionCount(msg.sender, courseId);
        
        // Record mint in educator contract
        educator.recordMint(msg.sender, rewardAmount);
        
        // Mint tokens to student
        token.mint(studentAddress, rewardAmount);
        
        emit CourseCompleted(
            studentAddress,
            courseId,
            msg.sender,
            rewardAmount,
            block.timestamp
        );
    }

    /**
     * @dev Pauses the system
     */
    function pause() external onlyRole(EducRoles.PAUSER_ROLE) {
        _pause();
    }

    /**
     * @dev Unpauses the system
     */
    function unpause() external onlyRole(EducRoles.PAUSER_ROLE) {
        _unpause();
    }
}