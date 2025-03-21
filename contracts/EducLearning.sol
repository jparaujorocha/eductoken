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
 * @dev Comprehensive integration contract for the educational ecosystem
 */
contract EducLearning is AccessControl, Pausable, ReentrancyGuard, Initializable {
    // Contract references
    EducToken public token;
    EducEducator public educator;
    EducStudent public student;
    EducCourse public course;
    EducConfig public config;
    EducPause public pauseControl;
    EducMultisig public multisig;
    EducProposal public proposal;

    // Enhanced events
    event SystemInitialized(
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

    event CourseCompletionProcessed(
        address indexed student,
        string courseId,
        address indexed educator,
        uint256 tokensAwarded,
        uint256 timestamp
    );

    /**
     * @dev Constructor sets up initial roles
     * @param admin Primary administrator address
     */
    constructor(address admin) {
        require(admin != address(0), "EducLearning: Invalid admin address");

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(EducRoles.ADMIN_ROLE, admin);
        _grantRole(EducRoles.PAUSER_ROLE, admin);
        _grantRole(EducRoles.UPGRADER_ROLE, admin);
    }

    /**
     * @dev Initializes the system with contract addresses
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
        // Comprehensive address validation
        require(_token != address(0), "EducLearning: Token address invalid");
        require(_educator != address(0), "EducLearning: Educator address invalid");
        require(_student != address(0), "EducLearning: Student address invalid");
        require(_course != address(0), "EducLearning: Course address invalid");
        require(_config != address(0), "EducLearning: Config address invalid");
        require(_pauseControl != address(0), "EducLearning: Pause control address invalid");
        require(_multisig != address(0), "EducLearning: Multisig address invalid");
        require(_proposal != address(0), "EducLearning: Proposal address invalid");

        // Initialize contract references
        token = EducToken(_token);
        educator = EducEducator(_educator);
        student = EducStudent(_student);
        course = EducCourse(_course);
        config = EducConfig(_config);
        pauseControl = EducPause(_pauseControl);
        multisig = EducMultisig(_multisig);
        proposal = EducProposal(_proposal);

        emit SystemInitialized(
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
     * @dev Processes course completion with comprehensive validation
     */
    function completeCourse(
        address studentAddress,
        string calldata courseId
    ) 
        external 
        whenNotPaused 
        nonReentrant 
    {
        // Comprehensive validation
        require(educator.isActiveEducator(msg.sender), "EducLearning: Caller not an active educator");
        require(course.isCourseActive(msg.sender, courseId), "EducLearning: Course not active");
        require(!student.hasCourseCompletion(studentAddress, courseId), "EducLearning: Course already completed");

        // Get course reward
        uint256 rewardAmount = course.getCourseReward(msg.sender, courseId);
        
        // Record course completion
        student.recordCourseCompletion(studentAddress, courseId, rewardAmount);
        course.incrementCompletionCount(msg.sender, courseId);
        educator.recordMint(msg.sender, rewardAmount);

        // Mint tokens
        token.mint(studentAddress, rewardAmount);

        emit CourseCompletionProcessed(
            studentAddress,
            courseId,
            msg.sender,
            rewardAmount,
            block.timestamp
        );
    }

    /**
     * @dev Pauses entire system
     */
    function pause() external onlyRole(EducRoles.PAUSER_ROLE) {
        _pause();
    }

    /**
     * @dev Unpauses entire system
     */
    function unpause() external onlyRole(EducRoles.PAUSER_ROLE) {
        _unpause();
    }
}