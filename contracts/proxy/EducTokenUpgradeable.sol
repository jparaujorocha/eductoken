// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "../access/roles/EducRoles.sol";
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
    // Total counters
    uint256 public totalMinted;
    uint256 public totalBurned;
    
    // Reference to student contract for activity tracking
    address public studentContract;
    
    // Daily minting tracking
    mapping(uint256 => uint256) public dailyMinting; // day number => amount minted

    // Role definitions
    bytes32 public constant ADMIN_ROLE = EducRoles.ADMIN_ROLE;
    bytes32 public constant EDUCATOR_ROLE = EducRoles.EDUCATOR_ROLE;
    bytes32 public constant MINTER_ROLE = EducRoles.MINTER_ROLE;
    bytes32 public constant UPGRADER_ROLE = EducRoles.UPGRADER_ROLE;

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
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializer function (replaces constructor)
     * @param admin The address that will be granted the admin role
     */
    function initialize(address admin) 
        public 
        initializer 
    {
        require(admin != address(0), "EducTokenUpgradeable: admin cannot be zero address");

        // Call parent initializers in the correct order
        __ERC20_init("EducToken", "EDUC");
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);

        _mint(admin, SystemConstants.INITIAL_SUPPLY);
        totalMinted = SystemConstants.INITIAL_SUPPLY;
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
        _validateMint(to, amount);
        _trackDailyMinting(amount);

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
        _validateMintReward(student, amount, reason);
        _trackDailyMinting(amount);
        
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
        _validateBatchMintReward(students, amounts, reasons);
        
        uint256 totalAmount = _calculateTotalAmount(amounts);
        _trackDailyMinting(totalAmount);
        
        for (uint256 i = 0; i < students.length; i++) {
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
        _validateBurn(_msgSender(), amount);

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
        _validateBurnFromInactive(from, amount);
        
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
        if (hasRole(ADMIN_ROLE, account)) {
            return false;
        }
        
        if (studentContract == address(0)) {
            return false;
        }
        
        bytes4 isStudentSelector = bytes4(keccak256("isStudent(address)"));
        (bool success, bytes memory result) = studentContract.staticcall(
            abi.encodeWithSelector(isStudentSelector, account)
        );
        
        if (!success || abi.decode(result, (bool)) == false) {
            return false;
        }
        
        bytes4 getLastActivitySelector = bytes4(keccak256("getStudentLastActivity(address)"));
        (success, result) = studentContract.staticcall(
            abi.encodeWithSelector(getLastActivitySelector, account)
        );
        
        if (!success) {
            return false;
        }
        
        uint256 lastActivity = abi.decode(result, (uint256));
        
        return lastActivity > 0 && (block.timestamp - lastActivity) > SystemConstants.BURN_COOLDOWN_PERIOD;
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

    function _validateMint(address to, uint256 amount) private pure {
        require(to != address(0), "EducTokenUpgradeable: mint to the zero address");
        require(amount > 0, "EducTokenUpgradeable: mint amount must be positive");
        require(amount <= SystemConstants.MAX_MINT_AMOUNT, "EducTokenUpgradeable: amount exceeds max mint amount");
    }

    function _validateMintReward(address student, uint256 amount, string calldata reason) private pure {
        _validateMint(student, amount);
        require(bytes(reason).length > 0, "EducTokenUpgradeable: reason cannot be empty");
    }

    function _validateBatchMintReward(
        address[] calldata students,
        uint256[] calldata amounts,
        string[] calldata reasons
    ) private pure {
        uint256 studentsLength = students.length;
        require(
            studentsLength == amounts.length && 
            studentsLength == reasons.length,
            "EducTokenUpgradeable: arrays length mismatch"
        );
        require(studentsLength > 0, "EducTokenUpgradeable: empty arrays");
        
        for (uint256 i = 0; i < studentsLength; i++) {
            _validateMintReward(students[i], amounts[i], reasons[i]);
        }
    }

    function _calculateTotalAmount(uint256[] calldata amounts) private pure returns (uint256 totalAmount) {
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }
    }

    function _trackDailyMinting(uint256 amount) private {
        uint256 today = block.timestamp / 1 days;
        dailyMinting[today] += amount;
        require(dailyMinting[today] <= SystemConstants.DAILY_MINT_LIMIT, "EducTokenUpgradeable: daily mint limit exceeded");
    }

    function _validateBurn(address account, uint256 amount) private view {
        require(amount > 0, "EducTokenUpgradeable: burn amount must be positive");
        require(balanceOf(account) >= amount, "EducTokenUpgradeable: burn amount exceeds balance");
    }

    function _validateBurnFromInactive(address from, uint256 amount) private view {
        require(from != address(0), "EducTokenUpgradeable: burn from the zero address");
        _validateBurn(from, amount);
        require(_isAccountInactive(from), "EducTokenUpgradeable: account is not inactive");
    }
}