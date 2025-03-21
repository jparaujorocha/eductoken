// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "../access/EducRoles.sol";

/**
 * @title EducConfig
 * @dev Configuration settings for the EducLearning ecosystem
 */
contract EducConfig is AccessControl, Pausable {
    // Role definitions
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // Configuration parameters
    uint16 public maxEducators;
    uint16 public maxCoursesPerEducator;
    uint256 public maxMintAmount;
    uint256 public mintCooldownPeriod;
    uint256 public lastUpdatedAt;

    // Events
    event ConfigUpdated(
        address indexed authority,
        uint256 timestamp
    );

    /**
     * @dev Initializes the configuration contract
     * @param admin The address that will be granted the admin role
     */
    constructor(address admin) {
        require(admin != address(0), "EducConfig: admin cannot be zero address");

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);

        // Set default values
        maxEducators = 1000;
        maxCoursesPerEducator = 100;
        maxMintAmount = 1000 * 10**18; // 1,000 tokens
        mintCooldownPeriod = 2 hours;
        lastUpdatedAt = block.timestamp;
    }

    /**
     * @dev Updates the configuration parameters
     * @param _maxEducators Maximum number of educators (0 to keep current)
     * @param _maxCoursesPerEducator Maximum courses per educator (0 to keep current)
     * @param _maxMintAmount Maximum mint amount per transaction (0 to keep current)
     * @param _mintCooldownPeriod Cooldown period between mints (0 to keep current)
     */
    function updateConfig(
        uint16 _maxEducators,
        uint16 _maxCoursesPerEducator,
        uint256 _maxMintAmount,
        uint256 _mintCooldownPeriod
    ) external onlyRole(ADMIN_ROLE) {
        bool updated = false;

        if (_maxEducators > 0) {
            maxEducators = _maxEducators;
            updated = true;
        }

        if (_maxCoursesPerEducator > 0) {
            maxCoursesPerEducator = _maxCoursesPerEducator;
            updated = true;
        }

        if (_maxMintAmount > 0) {
            maxMintAmount = _maxMintAmount;
            updated = true;
        }

        if (_mintCooldownPeriod > 0) {
            mintCooldownPeriod = _mintCooldownPeriod;
            updated = true;
        }

        if (updated) {
            lastUpdatedAt = block.timestamp;
            emit ConfigUpdated(msg.sender, block.timestamp);
        }
    }

    /**
     * @dev Pauses the configuration updates
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Unpauses the configuration updates
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
}