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
 * @dev Comprehensive integration contract for the educational ecosystem with enhanced reward system
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
    
    // Daily minting tracking
    uint256 public dailyMintingLimit;
    mapping(uint256 => uint256) public dailyMinting; // day => amount

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
    
    event RewardIssued(
        address indexed student,
        uint256 amount,
        string reason,
        address indexed educator,
        uint256 timestamp
    );
    
    event BatchRewardsIssued(
        address[] students,
        uint256 totalAmount,
        uint256 studentCount,
        address indexed educator,
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
        
        dailyMintingLimit = 1000 * 10**18; // 1000 tokens per day default limit
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
        
        // Set student contract in token for activity tracking
        token.setStudentContract(_student);

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
     * @dev Processes course completion with comprehensive validation and reward issuance
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
        
        // Track daily minting limits
        uint256 today = block.timestamp / 1 days;
        dailyMinting[today] += rewardAmount;
        require(dailyMinting[today] <= dailyMintingLimit, "EducLearning: Daily mint limit exceeded");
        
        // Record course completion
        student.recordCourseCompletion(studentAddress, courseId, rewardAmount);
        course.incrementCompletionCount(msg.sender, courseId);
        educator.recordMint(msg.sender, rewardAmount);

        // Mint tokens with specific reason
        string memory reason = string(abi.encodePacked(
            "Course Completion: ", courseId
        ));
        token.mintReward(studentAddress, rewardAmount, reason);

        emit CourseCompletionProcessed(
            studentAddress,
            courseId,
            msg.sender,
            rewardAmount,
            block.timestamp
        );
        
        emit RewardIssued(
            studentAddress,
            rewardAmount,
            reason,
            msg.sender,
            block.timestamp
        );
    }
    
    /**
     * @dev Issues additional educational rewards with tracking
     * @param studentAddress Student to reward
     * @param amount Amount of tokens to reward
     * @param reason Educational reason for the reward
     */
    function issueReward(
        address studentAddress,
        uint256 amount,
        string calldata reason
    )
        external
        whenNotPaused
        nonReentrant
    {
        require(educator.isActiveEducator(msg.sender), "EducLearning: Caller not an active educator");
        require(studentAddress != address(0), "EducLearning: Invalid student address");
        require(amount > 0, "EducLearning: Invalid reward amount");
        require(bytes(reason).length > 0, "EducLearning: Reason cannot be empty");
        
        // Validate student is registered, or register if not
        if (!student.isStudent(studentAddress)) {
            student.registerStudent(studentAddress);
        }
        
        // Track daily minting limits
        uint256 today = block.timestamp / 1 days;
        dailyMinting[today] += amount;
        require(dailyMinting[today] <= dailyMintingLimit, "EducLearning: Daily mint limit exceeded");
        
        // Record educator mint and student activity
        educator.recordMint(msg.sender, amount);
        student.recordCustomActivity(studentAddress, "Reward", reason);
        
        // Mint tokens
        token.mintReward(studentAddress, amount, reason);
        
        emit RewardIssued(
            studentAddress,
            amount,
            reason,
            msg.sender,
            block.timestamp
        );
    }
    
    /**
     * @dev Issues batch rewards to multiple students
     * @param students Array of student addresses
     * @param amounts Array of reward amounts
     * @param reasons Array of educational reasons
     */
    function batchIssueRewards(
        address[] calldata students,
        uint256[] calldata amounts,
        string[] calldata reasons
    )
        external
        whenNotPaused
        nonReentrant
    {
        require(educator.isActiveEducator(msg.sender), "EducLearning: Caller not an active educator");
        uint256 studentsLength = students.length;
        require(
            studentsLength == amounts.length && 
            studentsLength == reasons.length,
            "EducLearning: Arrays length mismatch"
        );
        require(studentsLength > 0, "EducLearning: Empty arrays");
        
        // Calculate total amount
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < studentsLength; i++) {
            require(students[i] != address(0), "EducLearning: Invalid student address");
            require(amounts[i] > 0, "EducLearning: Invalid reward amount");
            require(bytes(reasons[i]).length > 0, "EducLearning: Reason cannot be empty");
            
            totalAmount += amounts[i];
        }
        
        // Track daily minting limits
        uint256 today = block.timestamp / 1 days;
        dailyMinting[today] += totalAmount;
        require(dailyMinting[today] <= dailyMintingLimit, "EducLearning: Daily mint limit exceeded");
        
        // Record educator mint
        educator.recordMint(msg.sender, totalAmount);
        
        // Process each student
        for (uint256 i = 0; i < studentsLength; i++) {
            // Register student if needed
            if (!student.isStudent(students[i])) {
                student.registerStudent(students[i]);
            }
            
            // Record activity
            student.recordCustomActivity(students[i], "Reward", reasons[i]);
        }
        
        // Batch mint tokens
        token.batchMintReward(students, amounts, reasons);
        
        emit BatchRewardsIssued(
            students,
            totalAmount,
            studentsLength,
            msg.sender,
            block.timestamp
        );
    }
    
    /**
     * @dev Burns tokens from inactive accounts
     * @param studentAddress Address of the inactive student
     * @param amount Amount to burn
     */
    function burnInactiveTokens(
        address studentAddress,
        uint256 amount
    )
        external
        onlyRole(EducRoles.ADMIN_ROLE)
        whenNotPaused
        nonReentrant
    {
        require(studentAddress != address(0), "EducLearning: Invalid student address");
        require(amount > 0, "EducLearning: Invalid burn amount");
        require(student.isStudent(studentAddress), "EducLearning: Not a registered student");
        require(student.isStudentInactive(studentAddress), "EducLearning: Student is not inactive");
        require(token.isAccountInactive(studentAddress), "EducLearning: Token account is not inactive");
        
        string memory reason = "Account inactive for over 365 days";
        token.burnFromInactive(studentAddress, amount, reason);
    }
    
    /**
     * @dev Sets the daily minting limit
     * @param newLimit New daily minting limit
     */
    function setDailyMintingLimit(uint256 newLimit)
        external
        onlyRole(EducRoles.ADMIN_ROLE)
    {
        require(newLimit > 0, "EducLearning: Invalid limit");
        dailyMintingLimit = newLimit;
    }
    
    /**
     * @dev Gets the remaining daily minting capacity
     * @return Remaining amount that can be minted today
     */
    function getDailyMintingRemaining() external view returns (uint256) {
        uint256 today = block.timestamp / 1 days;
        uint256 usedToday = dailyMinting[today];
        
        if (usedToday >= dailyMintingLimit) {
            return 0;
        }
        
        return dailyMintingLimit - usedToday;
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