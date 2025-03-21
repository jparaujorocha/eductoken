// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../access/EducRoles.sol";
import "../interfaces/IEducToken.sol";
import "../interfaces/IEducStudent.sol";

/**
 * @title EducToken
 * @dev ERC20 token for educational incentives with enhanced reward system and activity tracking
 */
contract EducToken is ERC20, AccessControl, Pausable, ReentrancyGuard, IEducToken {
    // Constants
    uint256 public constant INITIAL_SUPPLY = 10_000_000 * 10**18; // 10 million tokens
    uint256 public constant MAX_MINT_AMOUNT = 100_000 * 10**18; // 100,000 tokens per transaction
    uint256 public constant BURN_COOLDOWN_PERIOD = 365 days; // 1 year for token expiration
    uint256 public constant DAILY_MINT_LIMIT = 1_000 * 10**18; // 1,000 tokens daily limit

    // Total counters
    uint256 public totalMinted;
    uint256 public totalBurned;
    
    // Reference to student contract for activity tracking
    IEducStudent public studentContract;
    
    // Daily minting tracking
    mapping(uint256 => uint256) public dailyMinting; // day number => amount minted

    // Role definitions from EducRoles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant EDUCATOR_ROLE = keccak256("EDUCATOR_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // Modifiers
    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "EducToken: caller is not an admin");
        _;
    }

    modifier onlyMinter() {
        require(hasRole(MINTER_ROLE, msg.sender), "EducToken: caller is not a minter");
        _;
    }

    /**
     * @dev Constructor that initializes the token with name, symbol and initial supply
     * @param admin The address that will be granted the admin role
     */
    constructor(address admin) ERC20("EducToken", "EDUC") {
        require(admin != address(0), "EducToken: admin cannot be zero address");

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);

        _mint(admin, INITIAL_SUPPLY);
        totalMinted = INITIAL_SUPPLY;
    }
    
    /**
     * @dev Sets the student contract address for activity tracking
     * @param _studentContract Address of the student contract
     */
    function setStudentContract(address _studentContract) external onlyAdmin {
        require(_studentContract != address(0), "EducToken: student contract cannot be zero address");
        studentContract = IEducStudent(_studentContract);
        emit StudentContractSet(_studentContract);
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
     * @dev Mints tokens to an address (generic version)
     * @param to The address that will receive the minted tokens
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) external override onlyMinter whenNotPaused nonReentrant {
        require(to != address(0), "EducToken: mint to the zero address");
        require(amount > 0, "EducToken: mint amount must be positive");
        require(amount <= MAX_MINT_AMOUNT, "EducToken: amount exceeds max mint amount");
        
        // Track daily minting limits
        uint256 today = block.timestamp / 1 days;
        dailyMinting[today] += amount;
        require(dailyMinting[today] <= DAILY_MINT_LIMIT, "EducToken: daily mint limit exceeded");

        _mint(to, amount);
        totalMinted += amount;

        emit TokensMinted(to, amount, msg.sender);
    }
    
    /**
     * @dev Mints tokens as educational rewards with detailed tracking
     * @param student The student address that will receive the reward
     * @param amount The amount of tokens to mint as reward
     * @param reason The educational reason for the reward
     */
    function mintReward(address student, uint256 amount, string calldata reason) 
        external 
        onlyMinter 
        whenNotPaused 
        nonReentrant 
    {
        require(student != address(0), "EducToken: mint to the zero address");
        require(amount > 0, "EducToken: mint amount must be positive");
        require(amount <= MAX_MINT_AMOUNT, "EducToken: amount exceeds max mint amount");
        require(bytes(reason).length > 0, "EducToken: reason cannot be empty");
        
        // Track daily minting limits
        uint256 today = block.timestamp / 1 days;
        dailyMinting[today] += amount;
        require(dailyMinting[today] <= DAILY_MINT_LIMIT, "EducToken: daily mint limit exceeded");
        
        _mint(student, amount);
        totalMinted += amount;
        
        emit RewardIssued(student, amount, reason);
        emit TokensMinted(student, amount, msg.sender);
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
        onlyMinter 
        whenNotPaused 
        nonReentrant 
    {
        uint256 studentsLength = students.length;
        require(
            studentsLength == amounts.length && 
            studentsLength == reasons.length,
            "EducToken: arrays length mismatch"
        );
        require(studentsLength > 0, "EducToken: empty arrays");
        
        // Calculate total amount and validate inputs
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < studentsLength; i++) {
            require(students[i] != address(0), "EducToken: mint to the zero address");
            require(amounts[i] > 0, "EducToken: mint amount must be positive");
            require(amounts[i] <= MAX_MINT_AMOUNT, "EducToken: amount exceeds max mint amount");
            require(bytes(reasons[i]).length > 0, "EducToken: reason cannot be empty");
            
            totalAmount += amounts[i];
        }
        
        // Track daily minting limits
        uint256 today = block.timestamp / 1 days;
        dailyMinting[today] += totalAmount;
        require(dailyMinting[today] <= DAILY_MINT_LIMIT, "EducToken: daily mint limit exceeded");
        
        // Process each student
        for (uint256 i = 0; i < studentsLength; i++) {
            _mint(students[i], amounts[i]);
            
            emit RewardIssued(students[i], amounts[i], reasons[i]);
            emit TokensMinted(students[i], amounts[i], msg.sender);
        }
        
        totalMinted += totalAmount;
    }

    /**
     * @dev Burns tokens from the caller's account
     * @param amount The amount of tokens to burn
     */
    function burn(uint256 amount) external override whenNotPaused nonReentrant {
        require(amount > 0, "EducToken: burn amount must be positive");
        require(balanceOf(msg.sender) >= amount, "EducToken: burn amount exceeds balance");

        _burn(msg.sender, amount);
        totalBurned += amount;

        emit TokensBurned(msg.sender, amount);
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
        onlyAdmin 
        whenNotPaused 
        nonReentrant 
    {
        require(from != address(0), "EducToken: burn from the zero address");
        require(amount > 0, "EducToken: burn amount must be positive");
        require(balanceOf(from) >= amount, "EducToken: burn amount exceeds balance");
        
        // Validate account inactivity 
        require(_isAccountInactive(from), "EducToken: account is not inactive");
        
        _burn(from, amount);
        totalBurned += amount;

        emit TokensBurnedFrom(from, amount, msg.sender, reason);
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
        // Admin accounts cannot be considered inactive
        if (hasRole(ADMIN_ROLE, account)) {
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
        return lastActivity > 0 && (block.timestamp - lastActivity) > BURN_COOLDOWN_PERIOD;
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
        
        if (usedToday >= DAILY_MINT_LIMIT) {
            return 0;
        }
        
        return DAILY_MINT_LIMIT - usedToday;
    }
}