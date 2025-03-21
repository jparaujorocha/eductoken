// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../access/EducRoles.sol";
import "../interfaces/IEducEducator.sol";

/**
 * @title EducEducator
 * @dev Manages educator accounts and permissions in the EducLearning system
 */
contract EducEducator is AccessControl, Pausable, ReentrancyGuard, IEducEducator {
    // Role definitions
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // Educator structure
    struct Educator {
        address educatorAddress;
        address authorityAddress;
        uint256 mintLimit;
        uint256 totalMinted;
        uint16 courseCount;
        bool isActive;
        uint256 createdAt;
        uint256 lastUpdatedAt;
        uint256 lastMintTime;
    }

    // Storage
    mapping(address => Educator) public educators;
    uint16 public totalEducators;

    // Constants
    uint256 public constant MAX_MINT_AMOUNT = 1_000_000 * 10**18; // 1M tokens with 18 decimals

    // Events
    event EducatorRegistered(
        address indexed educator,
        address indexed authority,
        uint256 mintLimit,
        uint256 timestamp
    );

    event EducatorStatusUpdated(
        address indexed educator,
        bool isActive,
        uint256 mintLimit,
        uint256 timestamp
    );

    /**
     * @dev Constructor that sets up the admin role
     * @param admin The address that will be granted the admin role
     */
    constructor(address admin) {
        require(admin != address(0), "EducEducator: admin cannot be zero address");

        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole(ADMIN_ROLE, admin);
        
        totalEducators = 0;
    }

    /**
     * @dev Registers a new educator
     * @param educator Address of the educator to register
     * @param mintLimit Maximum tokens the educator can mint
     */
    function registerEducator(address educator, uint256 mintLimit) 
        external 
        override 
        onlyRole(ADMIN_ROLE) 
        whenNotPaused 
        nonReentrant 
    {
        require(educator != address(0), "EducEducator: educator cannot be zero address");
        require(educators[educator].educatorAddress == address(0), "EducEducator: educator already registered");
        require(mintLimit > 0 && mintLimit <= MAX_MINT_AMOUNT, "EducEducator: invalid mint limit");
        require(totalEducators < type(uint16).max, "EducEducator: max educators limit reached");

        uint256 currentTime = block.timestamp;

        educators[educator] = Educator({
            educatorAddress: educator,
            authorityAddress: msg.sender,
            mintLimit: mintLimit,
            totalMinted: 0,
            courseCount: 0,
            isActive: true,
            createdAt: currentTime,
            lastUpdatedAt: currentTime,
            lastMintTime: 0
        });

        totalEducators++;

        emit EducatorRegistered(
            educator,
            msg.sender,
            mintLimit,
            currentTime
        );
    }

    /**
     * @dev Updates an educator's status
     * @param educator Address of the educator to update
     * @param isActive New active status
     * @param newMintLimit Optional new mint limit (0 to keep current)
     */
    function setEducatorStatus(
        address educator, 
        bool isActive, 
        uint256 newMintLimit
    ) 
        external 
        override 
        onlyRole(ADMIN_ROLE) 
        nonReentrant 
    {
        require(educators[educator].educatorAddress != address(0), "EducEducator: educator does not exist");

        uint256 currentTime = block.timestamp;
        Educator storage educatorData = educators[educator];
        
        educatorData.isActive = isActive;
        
        if (newMintLimit > 0 && newMintLimit <= MAX_MINT_AMOUNT) {
            educatorData.mintLimit = newMintLimit;
        }
        
        educatorData.lastUpdatedAt = currentTime;

        emit EducatorStatusUpdated(
            educator,
            isActive,
            educatorData.mintLimit,
            currentTime
        );
    }

    /**
     * @dev Updates educator's mint statistics
     * @param educator Address of the educator
     * @param amount Amount that was minted
     */
    function recordMint(address educator, uint256 amount) external override nonReentrant {
        require(hasRole(ADMIN_ROLE, msg.sender), "EducEducator: caller is not admin");
        require(educators[educator].educatorAddress != address(0), "EducEducator: educator does not exist");
        require(educators[educator].isActive, "EducEducator: educator is not active");

        Educator storage educatorData = educators[educator];
        educatorData.totalMinted += amount;
        educatorData.lastMintTime = block.timestamp;
    }

    /**
     * @dev Increases an educator's course count
     * @param educator Address of the educator
     */
    function incrementCourseCount(address educator) external override nonReentrant {
        require(hasRole(ADMIN_ROLE, msg.sender), "EducEducator: caller is not admin");
        require(educators[educator].educatorAddress != address(0), "EducEducator: educator does not exist");
        
        Educator storage educatorData = educators[educator];
        require(educatorData.courseCount < type(uint16).max, "EducEducator: max courses reached");
        
        educatorData.courseCount++;
    }

    /**
     * @dev Checks if an address is a registered and active educator
     * @param educator Address to check
     * @return bool True if address is an active educator
     */
    function isActiveEducator(address educator) external view override returns (bool) {
        return educators[educator].educatorAddress != address(0) && 
               educators[educator].isActive;
    }

    /**
     * @dev Gets an educator's mint limit
     * @param educator Address of the educator
     * @return uint256 The educator's mint limit
     */
    function getEducatorMintLimit(address educator) external view override returns (uint256) {
        require(educators[educator].educatorAddress != address(0), "EducEducator: educator does not exist");
        return educators[educator].mintLimit;
    }

    /**
     * @dev Gets an educator's total minted amount
     * @param educator Address of the educator
     * @return uint256 The educator's total minted amount
     */
    function getEducatorTotalMinted(address educator) external view override returns (uint256) {
        require(educators[educator].educatorAddress != address(0), "EducEducator: educator does not exist");
        return educators[educator].totalMinted;
    }

    /**
     * @dev Pauses educator management functions
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Unpauses educator management functions
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
}