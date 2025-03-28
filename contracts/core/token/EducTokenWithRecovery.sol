// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./EducToken.sol";
import "../../security/emergency/EducEmergencyEnabled.sol";
import "../../config/constants/SystemConstants.sol";
import "../../access/roles/EducRoles.sol";

/**
 * @title EducTokenWithRecovery
 * @dev ERC20 token for educational incentives with emergency recovery mechanisms
 */
contract EducTokenWithRecovery is 
    ERC20, 
    AccessControl, 
    Pausable, 
    ReentrancyGuard, 
    IEducToken,
    EducEmergencyEnabled 
{
    // Total counters
    uint256 public totalMinted;
    uint256 public totalBurned;
    
    // Reference to student contract for activity tracking
    IEducStudent public studentContract;
    
    // Daily minting tracking
    mapping(uint256 => uint256) public dailyMinting; // day number => amount minted

    /**
     * @dev Constructor that initializes the token with name, symbol and initial supply
     * @param admin The address that will be granted the admin role
     * @param treasury Address where recovered tokens will be sent in emergency
     * @param emergencyRecoveryContract Address of emergency recovery contract
     */
    constructor(
        address admin,
        address treasury,
        address emergencyRecoveryContract
    ) 
        ERC20("EducToken", "EDUC")
        EducEmergencyEnabled(treasury, emergencyRecoveryContract) 
    {
        require(admin != address(0), "EducToken: admin cannot be zero address");

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(EducRoles.ADMIN_ROLE, admin);
        _grantRole(EducRoles.MINTER_ROLE, admin);

        _mint(admin, SystemConstants.INITIAL_SUPPLY);
        totalMinted = SystemConstants.INITIAL_SUPPLY;
    }
    
    /**
     * @dev Sets the student contract address for activity tracking
     * @param _studentContract Address of the student contract
     */
    function setStudentContract(address _studentContract) external onlyRole(EducRoles.ADMIN_ROLE) {
        require(_studentContract != address(0), "EducToken: student contract cannot be zero address");
        studentContract = IEducStudent(_studentContract);
        emit TokenEvents.StudentContractSet(_studentContract);
    }

    /**
     * @dev Pauses all token transfers and minting operations
     */
    function pause() external onlyRole(EducRoles.ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Unpauses all token transfers and minting operations
     */
    function unpause() external onlyRole(EducRoles.ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @dev Mints tokens to an address (generic version)
     * @param to The address that will receive the minted tokens
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) external override onlyRole(EducRoles.MINTER_ROLE) whenNotPaused nonReentrant {
        validateMint(to, amount);
        trackDailyMinting(amount);

        _mint(to, amount);
        totalMinted += amount;

        emit TokenEvents.TokensMinted(to, amount, msg.sender);
    }
    
    /**
     * @dev Mints tokens as educational rewards with detailed tracking
     * @param student The student address that will receive the reward
     * @param amount The amount of tokens to mint as reward
     * @param reason The educational reason for the reward
     */
    function mintReward(address student, uint256 amount, string calldata reason) 
        external 
        onlyRole(EducRoles.MINTER_ROLE) 
        whenNotPaused 
        nonReentrant 
    {
        validateMint(student, amount);
        require(bytes(reason).length > 0, "EducToken: reason cannot be empty");
        trackDailyMinting(amount);
        
        _mint(student, amount);
        totalMinted += amount;
        
        emit TokenEvents.RewardIssued(student, amount, reason);
        emit TokenEvents.TokensMinted(student, amount, msg.sender);
    }
    
    function mintReward(TokenTypes.MintRewardParams calldata params) external override 
    onlyRole(EducRoles.MINTER_ROLE) 
    whenNotPaused 
    nonReentrant 
    {
        validateMint(params.student, params.amount);
        require(bytes(params.reason).length > 0, "EducToken: reason cannot be empty");
        trackDailyMinting(params.amount);
        
        _mint(params.student, params.amount);
        totalMinted += params.amount;
        
        emit TokenEvents.RewardIssued(params.student, params.amount, params.reason);
        emit TokenEvents.TokensMinted(params.student, params.amount, msg.sender);
    }

    function batchMintReward(TokenTypes.BatchMintRewardParams calldata params) external override 
        onlyRole(EducRoles.MINTER_ROLE) 
        whenNotPaused 
        nonReentrant 
    {
        validateBatchMint(params.students, params.amounts, params.reasons);
        uint256 totalAmount = calculateTotalAmount(params.amounts);
        trackDailyMinting(totalAmount);
        
        for (uint256 i = 0; i < params.students.length; i++) {
            _mint(params.students[i], params.amounts[i]);
            
            emit TokenEvents.RewardIssued(params.students[i], params.amounts[i], params.reasons[i]);
            emit TokenEvents.TokensMinted(params.students[i], params.amounts[i], msg.sender);
        }
        
        totalMinted += totalAmount;
    }

    function burnFromInactive(TokenTypes.BurnInactiveParams calldata params) external override 
        onlyRole(EducRoles.ADMIN_ROLE) 
        whenNotPaused 
        nonReentrant 
    {
        validateBurn(params.from, params.amount);
        require(_isAccountInactive(params.from), "EducToken: account is not inactive");
        
        _burn(params.from, params.amount);
        totalBurned += params.amount;

        emit TokenEvents.TokensBurnedFrom(params.from, params.amount, msg.sender, params.reason);
    }

    function getTotalMinted() external view override returns (uint256 amount) {
        return totalMinted;
    }

    function getTotalBurned() external view override returns (uint256 amount) {
        return totalBurned;
    }

    /**
     * @dev Batch mints tokens as educational rewards to multiple students
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
        onlyRole(EducRoles.MINTER_ROLE) 
        whenNotPaused 
        nonReentrant 
    {
        validateBatchMint(students, amounts, reasons);
        uint256 totalAmount = calculateTotalAmount(amounts);
        trackDailyMinting(totalAmount);
        
        for (uint256 i = 0; i < students.length; i++) {
            _mint(students[i], amounts[i]);
            
            emit TokenEvents.RewardIssued(students[i], amounts[i], reasons[i]);
            emit TokenEvents.TokensMinted(students[i], amounts[i], msg.sender);
        }
        
        totalMinted += totalAmount;
    }

    /**
     * @dev Burns tokens from the caller's account
     * @param amount The amount of tokens to burn
     */
    function burn(uint256 amount) external override whenNotPaused nonReentrant {
        validateBurn(msg.sender, amount);

        _burn(msg.sender, amount);
        totalBurned += amount;

        emit TokenEvents.TokensBurned(msg.sender, amount);
    }

    /**
     * @dev Burns tokens from inactive accounts
     * @param from The address from which to burn tokens
     * @param amount The amount of tokens to burn
     * @param reason The reason for burning tokens
     */
    function burnFromInactive(address from, uint256 amount, string calldata reason) 
        external 
        override 
        onlyRole(EducRoles.ADMIN_ROLE) 
        whenNotPaused 
        nonReentrant 
    {
        validateBurn(from, amount);
        require(_isAccountInactive(from), "EducToken: account is not inactive");
        
        _burn(from, amount);
        totalBurned += amount;

        emit TokenEvents.TokensBurnedFrom(from, amount, msg.sender, reason);
    }

    /**
     * @dev Transfer function override to enforce pause logic
     */
    function transfer(address to, uint256 amount) public override(ERC20, IEducToken) whenNotPaused returns (bool) {
        return super.transfer(to, amount);
    }

    /**
     * @dev TransferFrom function override to enforce pause logic
     */
    function transferFrom(address from, address to, uint256 amount) 
        public 
        override(ERC20, IEducToken) 
        whenNotPaused 
        returns (bool) 
    {
        return super.transferFrom(from, to, amount);
    }

    /**
     * @dev Determines if an account is considered inactive
     * @param account The account to check
     * @return bool True if the account is inactive and eligible for token expiration
     */
    function _isAccountInactive(address account) internal view returns (bool) {
        if (isAdmin(account) || !isStudentContractSet() || !isRegisteredStudent(account)) {
            return false;
        }
        
        uint256 lastActivity = studentContract.getStudentLastActivity(account);
        return isInactiveForPeriod(lastActivity);
    }
    
    /**
     * @dev Gets whether an account is currently inactive
     * @param account The account to check
     * @return bool True if the account is inactive
     */
    function isAccountInactive(address account) external view returns (bool) {
        return _isAccountInactive(account);
    }
    
    /**
     * @dev Gets the remaining daily minting capacity
     * @return uint256 The amount of tokens that can still be minted today
     */
    function getDailyMintingRemaining() external view returns (uint256) {
        uint256 today = block.timestamp / 1 days;
        uint256 usedToday = dailyMinting[today];
        
        if (usedToday >= SystemConstants.DAILY_MINT_LIMIT) {
            return 0;
        }
        
        return SystemConstants.DAILY_MINT_LIMIT - usedToday;
    }

    // Private helper functions

    function validateMint(address to, uint256 amount) private pure {
        require(to != address(0), "EducToken: mint to the zero address");
        require(amount > 0, "EducToken: mint amount must be positive");
        require(amount <= SystemConstants.MAX_MINT_AMOUNT, "EducToken: amount exceeds max mint amount");
    }

    function validateBurn(address from, uint256 amount) private view {
        require(from != address(0), "EducToken: burn from the zero address");
        require(amount > 0, "EducToken: burn amount must be positive");
        require(balanceOf(from) >= amount, "EducToken: burn amount exceeds balance");
    }

    function validateBatchMint(address[] calldata students, uint256[] calldata amounts, string[] calldata reasons) private pure {
        uint256 studentsLength = students.length;
        require(
            studentsLength == amounts.length && 
            studentsLength == reasons.length,
            "EducToken: arrays length mismatch"
        );
        require(studentsLength > 0, "EducToken: empty arrays");
        
        for (uint256 i = 0; i < studentsLength; i++) {
            require(students[i] != address(0), "EducToken: mint to the zero address");
            require(amounts[i] > 0, "EducToken: mint amount must be positive");
            require(amounts[i] <= SystemConstants.MAX_MINT_AMOUNT, "EducToken: amount exceeds max mint amount");
            require(bytes(reasons[i]).length > 0, "EducToken: reason cannot be empty");
        }
    }

    function trackDailyMinting(uint256 amount) private {
        uint256 today = block.timestamp / 1 days;
        dailyMinting[today] += amount;
        require(dailyMinting[today] <= SystemConstants.DAILY_MINT_LIMIT, "EducToken: daily mint limit exceeded");
    }

    function calculateTotalAmount(uint256[] calldata amounts) private pure returns (uint256 totalAmount) {
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }
    }

    function isAdmin(address account) private view returns (bool) {
        return hasRole(EducRoles.ADMIN_ROLE, account);
    }

    function isStudentContractSet() private view returns (bool) {
        return address(studentContract) != address(0);
    }

    function isRegisteredStudent(address account) private view returns (bool) {
        return studentContract.isStudent(account);
    }

    function isInactiveForPeriod(uint256 lastActivity) private view returns (bool) {
        return lastActivity > 0 && (block.timestamp - lastActivity) > SystemConstants.BURN_COOLDOWN_PERIOD;
    }
}