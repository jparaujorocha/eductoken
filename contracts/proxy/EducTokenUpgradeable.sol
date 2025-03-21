// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "../access/roles/EducRoles.sol";
import "../interfaces/IEducToken.sol";
import "./interfaces/IUpgradeable.sol";
import "../interfaces/IEducStudent.sol";
import "../config/constants/SystemConstants.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";


/**
 * @title EducTokenUpgradeable
 * @dev Upgradeable version of EducToken contract with UUPS proxy pattern
 */
contract EducTokenUpgradeable is 
    Initializable,
    ERC20Upgradeable,
    AccessControlUpgradeable, 
    PausableUpgradeable, 
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    // Constants
    uint256 public constant INITIAL_SUPPLY = 10_000_000 * 10**18; // 10 million tokens
    uint256 public constant MAX_MINT_AMOUNT = 100_000 * 10**18; // 100,000 tokens per transaction
    uint256 public constant BURN_COOLDOWN_PERIOD = 365 days; // 1 year for token expiration
    uint256 public constant DAILY_MINT_LIMIT = 1_000 * 10**18; // 1,000 tokens daily limit

    // Total counters
    uint256 public totalMinted;
    uint256 public totalBurned;
    
    // Reference to student contract for activity tracking
    address public studentContract;
    
    // Daily minting tracking
    mapping(uint256 => uint256) public dailyMinting; // day number => amount minted

    // Role definitions
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant EDUCATOR_ROLE = keccak256("EDUCATOR_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // Events
    event TokensMinted(address indexed to, uint256 amount, address indexed minter);
    event TokensBurned(address indexed from, uint256 amount);
    event TokensBurnedFrom(address indexed from, uint256 amount, address indexed burner, string reason);
    event RewardIssued(address indexed student, uint256 amount, string reason);
    event StudentContractSet(address indexed studentContract);

    /**
     * @dev Constructor is empty as this is an upgradeable contract
     * Use initialize() instead
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    /**
     * @dev Initializer function (replaces constructor)
     * @param admin The address that will be granted the admin role
     */
    function initialize(address admin) 
        public 
        initializer 
    {
        require(admin != address(0), "EducTokenUpgradeable: admin cannot be zero address");

        __ERC20_init("EducToken", "EDUC");
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);

        _mint(admin, INITIAL_SUPPLY);
        totalMinted = INITIAL_SUPPLY;
    }

    /**
     * @dev Sets the student contract address for activity tracking
     * @param _studentContract Address of the student contract
     */
    function setStudentContract(address _studentContract) 
        external
        onlyRole(ADMIN_ROLE) 
    {
        require(_studentContract != address(0), "EducTokenUpgradeable: student contract cannot be zero address");
        studentContract = _studentContract;
        emit StudentContractSet(_studentContract);
    }

    /**
     * @dev Pauses all token transfers and minting operations
     */
    function pause() 
        external
        onlyRole(ADMIN_ROLE) 
    {
        _pause();
    }

    /**
     * @dev Unpauses all token transfers and minting operations
     */
    function unpause() 
        external
        onlyRole(ADMIN_ROLE) 
    {
        _unpause();
    }

    /**
     * @dev Mints tokens to an address
     * @param to The address that will receive the minted tokens
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) 
        external
        onlyRole(MINTER_ROLE) 
        whenNotPaused 
        nonReentrant 
    {
        require(to != address(0), "EducTokenUpgradeable: mint to the zero address");
        require(amount > 0, "EducTokenUpgradeable: mint amount must be positive");
        require(amount <= MAX_MINT_AMOUNT, "EducTokenUpgradeable: amount exceeds max mint amount");
        
        // Track daily minting limits
        uint256 today = block.timestamp / 1 days;
        dailyMinting[today] += amount;
        require(dailyMinting[today] <= DAILY_MINT_LIMIT, "EducTokenUpgradeable: daily mint limit exceeded");

        _mint(to, amount);
        totalMinted += amount;

        emit TokensMinted(to, amount, _msgSender());
    }
    
    /**
     * @dev Mints tokens as educational rewards with detailed tracking
     * @param student The student address that will receive the reward
     * @param amount The amount of tokens to mint as reward
     * @param reason The educational reason for the reward
     */
    function mintReward(address student, uint256 amount, string calldata reason) 
        external 
        onlyRole(MINTER_ROLE) 
        whenNotPaused 
        nonReentrant 
    {
        require(student != address(0), "EducTokenUpgradeable: mint to the zero address");
        require(amount > 0, "EducTokenUpgradeable: mint amount must be positive");
        require(amount <= MAX_MINT_AMOUNT, "EducTokenUpgradeable: amount exceeds max mint amount");
        require(bytes(reason).length > 0, "EducTokenUpgradeable: reason cannot be empty");
        
        // Track daily minting limits
        uint256 today = block.timestamp / 1 days;
        dailyMinting[today] += amount;
        require(dailyMinting[today] <= DAILY_MINT_LIMIT, "EducTokenUpgradeable: daily mint limit exceeded");
        
        _mint(student, amount);
        totalMinted += amount;
        
        emit RewardIssued(student, amount, reason);
        emit TokensMinted(student, amount, _msgSender());
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
        onlyRole(MINTER_ROLE) 
        whenNotPaused 
        nonReentrant 
    {
        uint256 studentsLength = students.length;
        require(
            studentsLength == amounts.length && 
            studentsLength == reasons.length,
            "EducTokenUpgradeable: arrays length mismatch"
        );
        require(studentsLength > 0, "EducTokenUpgradeable: empty arrays");
        
        // Calculate total amount and validate inputs
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < studentsLength; i++) {
            require(students[i] != address(0), "EducTokenUpgradeable: mint to the zero address");
            require(amounts[i] > 0, "EducTokenUpgradeable: mint amount must be positive");
            require(amounts[i] <= MAX_MINT_AMOUNT, "EducTokenUpgradeable: amount exceeds max mint amount");
            require(bytes(reasons[i]).length > 0, "EducTokenUpgradeable: reason cannot be empty");
            
            totalAmount += amounts[i];
        }
        
        // Track daily minting limits
        uint256 today = block.timestamp / 1 days;
        dailyMinting[today] += totalAmount;
        require(dailyMinting[today] <= DAILY_MINT_LIMIT, "EducTokenUpgradeable: daily mint limit exceeded");
        
        // Process each student
        for (uint256 i = 0; i < studentsLength; i++) {
            _mint(students[i], amounts[i]);
            
            emit RewardIssued(students[i], amounts[i], reasons[i]);
            emit TokensMinted(students[i], amounts[i], _msgSender());
        }
        
        totalMinted += totalAmount;
    }

    /**
     * @dev Burns tokens from the caller's account
     * @param amount The amount of tokens to burn
     */
    function burn(uint256 amount) 
        external 
        whenNotPaused 
        nonReentrant 
    {
        require(amount > 0, "EducTokenUpgradeable: burn amount must be positive");
        require(balanceOf(_msgSender()) >= amount, "EducTokenUpgradeable: burn amount exceeds balance");

        _burn(_msgSender(), amount);
        totalBurned += amount;

        emit TokensBurned(_msgSender(), amount);
    }

    /**
     * @dev Burns tokens from inactive accounts
     * @param from The address from which to burn tokens
     * @param amount The amount of tokens to burn
     * @param reason The reason for burning tokens
     */
    function burnFromInactive(address from, uint256 amount, string calldata reason) 
        external 
        onlyRole(ADMIN_ROLE) 
        whenNotPaused 
        nonReentrant 
    {
        require(from != address(0), "EducTokenUpgradeable: burn from the zero address");
        require(amount > 0, "EducTokenUpgradeable: burn amount must be positive");
        require(balanceOf(from) >= amount, "EducTokenUpgradeable: burn amount exceeds balance");
        
        // Validate account inactivity 
        require(_isAccountInactive(from), "EducTokenUpgradeable: account is not inactive");
        
        _burn(from, amount);
        totalBurned += amount;

        emit TokensBurnedFrom(from, amount, _msgSender(), reason);
    }

    /**
     * @dev Transfer function override to enforce pause logic
     */
    function transfer(address to, uint256 amount) 
        public 
        override 
        whenNotPaused 
        returns (bool) 
    {
        return super.transfer(to, amount);
    }

    /**
     * @dev TransferFrom function override to enforce pause logic
     */
    function transferFrom(address from, address to, uint256 amount) 
        public 
        override 
        whenNotPaused 
        returns (bool) 
    {
        return super.transferFrom(from, to, amount);
    }

    /**
     * @dev Required override for UUPS proxy pattern - ensures only authorized accounts can upgrade
     */
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}

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
        if (studentContract == address(0)) {
            return false;
        }
        
        // Check if this is a registered student
        bytes4 isStudentSelector = bytes4(keccak256("isStudent(address)"));
        (bool success, bytes memory result) = studentContract.staticcall(
            abi.encodeWithSelector(isStudentSelector, account)
        );
        
        if (!success || abi.decode(result, (bool)) == false) {
            return false;
        }
        
        // Get last activity timestamp from student contract
        bytes4 getLastActivitySelector = bytes4(keccak256("getStudentLastActivity(address)"));
        (success, result) = studentContract.staticcall(
            abi.encodeWithSelector(getLastActivitySelector, account)
        );
        
        if (!success) {
            return false;
        }
        
        uint256 lastActivity = abi.decode(result, (uint256));
        
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