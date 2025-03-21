// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../../access/roles/EducRoles.sol";
import "../../interfaces/IEducToken.sol";
import "../../interfaces/IEducStudent.sol";
import "../../config/constants/SystemConstants.sol";
import "./TokenEvents.sol";
import "./types/TokenTypes.sol";

/**
 * @title EducToken
 * @dev ERC20 token for educational incentives with enhanced reward system and activity tracking
 */
contract EducToken is ERC20, AccessControl, Pausable, ReentrancyGuard, IEducToken {
    // Total counters
    uint256 public totalMinted;
    uint256 public totalBurned;
    
    // Reference to student contract for activity tracking
    IEducStudent public studentContract;
    
    // Daily minting tracking
    mapping(uint256 => uint256) public dailyMinting; // day number => amount minted

    // Modifiers
    modifier onlyAdmin() {
        require(hasRole(EducRoles.ADMIN_ROLE, msg.sender), "EducToken: caller is not an admin");
        _;
    }

    modifier onlyMinter() {
        require(hasRole(EducRoles.MINTER_ROLE, msg.sender), "EducToken: caller is not a minter");
        _;
    }

    modifier validAddress(address account) {
        require(account != address(0), "EducToken: zero address not allowed");
        _;
    }

    modifier positiveAmount(uint256 amount) {
        require(amount > 0, "EducToken: amount must be positive");
        _;
    }

    /**
     * @dev Constructor that initializes the token with name, symbol and initial supply
     * @param admin The address that will be granted the admin role
     */
    constructor(address admin) ERC20("EducToken", "EDUC") validAddress(admin) {
        _setupRoles(admin);
        _mintInitialSupply(admin);
    }
    
    /**
     * @dev Sets up the initial roles for the token
     * @param admin Admin address to receive roles
     */
    function _setupRoles(address admin) private {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(EducRoles.ADMIN_ROLE, admin);
        _grantRole(EducRoles.MINTER_ROLE, admin);
    }
    
    /**
     * @dev Mints the initial token supply to the admin
     * @param admin Address to receive initial supply
     */
    function _mintInitialSupply(address admin) private {
        _mint(admin, SystemConstants.INITIAL_SUPPLY);
        totalMinted = SystemConstants.INITIAL_SUPPLY;
    }
    
    /**
     * @dev Sets the student contract address for activity tracking
     * @param _studentContract Address of the student contract
     */
    function setStudentContract(address _studentContract) 
        external 
        onlyAdmin 
        validAddress(_studentContract)
    {
        studentContract = IEducStudent(_studentContract);
        emit TokenEvents.StudentContractSet(_studentContract);
    }

    /**
     * @dev Pauses all token transfers and minting operations
     */
    function pause() external onlyAdmin {
        _pause();
    }

    /**
     * @dev Unpauses all token transfers and minting operations
     */
    function unpause() external onlyAdmin {
        _unpause();
    }

    /**
     * @dev Mints tokens to an address
     * @param to The address that will receive the minted tokens
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) 
        external 
        override 
        onlyMinter 
        whenNotPaused 
        nonReentrant 
        validAddress(to) 
        positiveAmount(amount)
    {
        _validateMintAmount(amount);
        _trackDailyMinting(amount);
        _performMint(to, amount);
        
        emit TokenEvents.TokensMinted(to, amount, msg.sender);
    }
    
    /**
     * @dev Mints tokens as educational rewards with structured parameters
     * @param params Structured mint reward parameters
     */
    function mintReward(TokenTypes.MintRewardParams calldata params)
        external
        onlyMinter
        whenNotPaused
        nonReentrant
        validAddress(params.student)
        positiveAmount(params.amount)
    {
        require(bytes(params.reason).length > 0, "EducToken: reason cannot be empty");
        
        _validateMintAmount(params.amount);
        _trackDailyMinting(params.amount);
        _performMint(params.student, params.amount);
        
        emit TokenEvents.RewardIssued(params.student, params.amount, params.reason);
        emit TokenEvents.TokensMinted(params.student, params.amount, msg.sender);
    }
    
    /**
     * @dev Legacy method for compatibility - mints tokens as educational rewards
     * @param student The student address that will receive the reward
     * @param amount The amount of tokens to mint as reward
     * @param reason The educational reason for the reward
     */
    function mintReward(address student, uint256 amount, string calldata reason) 
        external 
        override
        onlyMinter 
        whenNotPaused 
        nonReentrant 
        validAddress(student)
        positiveAmount(amount)
    {
        require(bytes(reason).length > 0, "EducToken: reason cannot be empty");
        
        _validateMintAmount(amount);
        _trackDailyMinting(amount);
        _performMint(student, amount);
        
        emit TokenEvents.RewardIssued(student, amount, reason);
        emit TokenEvents.TokensMinted(student, amount, msg.sender);
    }
    
    /**
     * @dev Batch mints tokens as educational rewards with structured parameters
     * @param params Structured batch mint parameters
     */
    function batchMintReward(TokenTypes.BatchMintRewardParams calldata params)
        external
        onlyMinter
        whenNotPaused
        nonReentrant
    {
        _validateBatchInputs(params.students, params.amounts, params.reasons);
        
        // Calculate total amount and validate inputs
        uint256 totalAmount = _validateAndSumBatchAmounts(params.students, params.amounts, params.reasons);
        
        // Track daily minting limits for the total amount
        _trackDailyMinting(totalAmount);
        
        // Process each student
        _performBatchMint(params.students, params.amounts, params.reasons);
        
        totalMinted += totalAmount;
    }
    
    /**
     * @dev Legacy method for compatibility - batch mints tokens as educational rewards
     * @param students Array of student addresses
     * @param amounts Array of token amounts
     * @param reasons Array of educational reasons
     */
    function batchMintReward(
        address[] calldata students,
        uint256[] calldata amounts,
        string[] calldata reasons
    ) 
        external 
        override
        onlyMinter 
        whenNotPaused 
        nonReentrant 
    {
        _validateBatchInputs(students, amounts, reasons);
        
        // Calculate total amount and validate inputs
        uint256 totalAmount = _validateAndSumBatchAmounts(students, amounts, reasons);
        
        // Track daily minting limits for the total amount
        _trackDailyMinting(totalAmount);
        
        // Process each student
        _performBatchMint(students, amounts, reasons);
        
        totalMinted += totalAmount;
    }

    /**
     * @dev Burns tokens from the caller's account
     * @param amount The amount of tokens to burn
     */
    function burn(uint256 amount) 
        external 
        override 
        whenNotPaused 
        nonReentrant 
        positiveAmount(amount)
    {
        require(balanceOf(msg.sender) >= amount, "EducToken: burn amount exceeds balance");

        _burn(msg.sender, amount);
        totalBurned += amount;

        emit TokenEvents.TokensBurned(msg.sender, amount);
    }

    /**
     * @dev Burns tokens from inactive accounts with structured parameters
     * @param params Structured burn parameters
     */
    function burnFromInactive(TokenTypes.BurnInactiveParams calldata params)
        external
        onlyAdmin
        whenNotPaused
        nonReentrant
        validAddress(params.from)
        positiveAmount(params.amount)
    {
        require(balanceOf(params.from) >= params.amount, "EducToken: burn amount exceeds balance");
        
        // Validate account inactivity 
        require(_isAccountInactive(params.from), "EducToken: account is not inactive");
        
        _burn(params.from, params.amount);
        totalBurned += params.amount;

        emit TokenEvents.TokensBurnedFrom(params.from, params.amount, msg.sender, params.reason);
    }
    
    /**
     * @dev Legacy method for compatibility - burns tokens from inactive accounts
     * @param from The address from which to burn tokens
     * @param amount The amount of tokens to burn
     * @param reason The reason for burning tokens
     */
    function burnFromInactive(address from, uint256 amount, string calldata reason) 
        external 
        override 
        onlyAdmin 
        whenNotPaused 
        nonReentrant 
        validAddress(from)
        positiveAmount(amount)
    {
        require(balanceOf(from) >= amount, "EducToken: burn amount exceeds balance");
        
        // Validate account inactivity 
        require(_isAccountInactive(from), "EducToken: account is not inactive");
        
        _burn(from, amount);
        totalBurned += amount;

        emit TokenEvents.TokensBurnedFrom(from, amount, msg.sender, reason);
    }

    /**
     * @dev Transfer function override to enforce pause logic
     */
    function transfer(address to, uint256 amount) 
        public 
        override(ERC20, IEducToken) 
        whenNotPaused 
        returns (bool) 
    {
        return super.transfer(to, amount);
    }

    /**
     * @dev TransferFrom function override to enforce pause logic
     */
    function transferFrom(
        address from, 
        address to, 
        uint256 amount
    ) 
        public 
        override(ERC20, IEducToken) 
        whenNotPaused 
        returns (bool) 
    {
        return super.transferFrom(from, to, amount);
    }

    /**
     * @dev Validates the mint amount is within limits
     * @param amount Amount to validate
     */
    function _validateMintAmount(uint256 amount) private pure {
        require(amount <= SystemConstants.MAX_MINT_AMOUNT, "EducToken: amount exceeds max mint amount");
    }
    
    /**
     * @dev Tracks daily minting limits
     * @param amount Amount to add to today's minting
     */
    function _trackDailyMinting(uint256 amount) private {
        uint256 today = block.timestamp / SystemConstants.ONE_DAY;
        dailyMinting[today] += amount;
        require(dailyMinting[today] <= SystemConstants.DAILY_MINT_LIMIT, "EducToken: daily mint limit exceeded");
    }
    
    /**
     * @dev Performs the actual minting operation
     * @param to Recipient address
     * @param amount Amount to mint
     */
    function _performMint(address to, uint256 amount) private {
        _mint(to, amount);
        totalMinted += amount;
    }
    
    /**
     * @dev Validates batch minting inputs
     * @param students Student addresses
     * @param amounts Token amounts
     * @param reasons Minting reasons
     */
    function _validateBatchInputs(
        address[] calldata students,
        uint256[] calldata amounts,
        string[] calldata reasons
    ) private pure {
        uint256 studentsLength = students.length;
        require(
            studentsLength == amounts.length && 
            studentsLength == reasons.length,
            "EducToken: arrays length mismatch"
        );
        require(studentsLength > 0, "EducToken: empty arrays");
    }
    
    /**
     * @dev Validates and sums batch amounts
     * @param students Student addresses
     * @param amounts Token amounts
     * @param reasons Minting reasons
     * @return totalAmount Sum of all amounts
     */
    function _validateAndSumBatchAmounts(
        address[] calldata students,
        uint256[] calldata amounts,
        string[] calldata reasons
    ) private pure returns (uint256 totalAmount) {
        totalAmount = 0;
        
        for (uint256 i = 0; i < students.length; i++) {
            require(students[i] != address(0), "EducToken: mint to the zero address");
            require(amounts[i] > 0, "EducToken: mint amount must be positive");
            require(amounts[i] <= SystemConstants.MAX_MINT_AMOUNT, "EducToken: amount exceeds max mint amount");
            require(bytes(reasons[i]).length > 0, "EducToken: reason cannot be empty");
            
            totalAmount += amounts[i];
        }
        
        return totalAmount;
    }
    
    /**
     * @dev Performs batch minting to multiple recipients
     * @param students Student addresses
     * @param amounts Token amounts
     * @param reasons Minting reasons
     */
    function _performBatchMint(
        address[] calldata students,
        uint256[] calldata amounts,
        string[] calldata reasons
    ) private {
        for (uint256 i = 0; i < students.length; i++) {
            _mint(students[i], amounts[i]);
            
            emit TokenEvents.RewardIssued(students[i], amounts[i], reasons[i]);
            emit TokenEvents.TokensMinted(students[i], amounts[i], msg.sender);
        }
    }

    /**
     * @dev Determines if an account is considered inactive
     * @param account The account to check
     * @return bool True if the account is inactive and eligible for token expiration
     */
    function _isAccountInactive(address account) internal view returns (bool) {
        // Admin accounts cannot be considered inactive
        if (hasRole(EducRoles.ADMIN_ROLE, account)) {
            return false;
        }
        
        // If student contract is not set, accounts cannot be inactive
        if (address(studentContract) == address(0)) {
            return false;
        }
        
        // Check if this is a registered student
        if (!studentContract.isStudent(account)) {
            return false;
        }
        
        // Get last activity timestamp from student contract
        uint256 lastActivity = studentContract.getStudentLastActivity(account);
        
        // Account is inactive if no activity for BURN_COOLDOWN_PERIOD (1 year)
        return lastActivity > 0 && (block.timestamp - lastActivity) > SystemConstants.BURN_COOLDOWN_PERIOD;
    }
    
    /**
     * @dev Gets whether an account is currently inactive
     * @param account The account to check
     * @return isInactive True if the account is inactive
     */
    function isAccountInactive(address account) external view override returns (bool isInactive) {
        return _isAccountInactive(account);
    }
    
    /**
     * @dev Gets the remaining daily minting capacity
     * @return remaining The amount of tokens that can still be minted today
     */
    function getDailyMintingRemaining() external view override returns (uint256 remaining) {
        uint256 today = block.timestamp / SystemConstants.ONE_DAY;
        uint256 usedToday = dailyMinting[today];
        
        if (usedToday >= SystemConstants.DAILY_MINT_LIMIT) {
            return 0;
        }
        
        return SystemConstants.DAILY_MINT_LIMIT - usedToday;
    }
    
    /**
     * @dev Gets the total amount of tokens minted since contract deployment
     * @return amount Total minted amount
     */
    function getTotalMinted() external view override returns (uint256 amount) {
        return totalMinted;
    }
    
    /**
     * @dev Gets the total amount of tokens burned since contract deployment
     * @return amount Total burned amount
     */
    function getTotalBurned() external view override returns (uint256 amount) {
        return totalBurned;
    }
}