// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "../access/roles/EducRoles.sol";
import "./constants/SystemConstants.sol";

/**
 * @title EducConfig
 * @dev Advanced configuration management for the educational ecosystem
 */
contract EducConfig is AccessControl, Pausable {
    // Configuration parameters with enhanced tracking
    struct SystemConfig {
        uint16 maxEducators;
        uint16 maxCoursesPerEducator;
        uint256 maxMintAmount;
        uint256 mintCooldownPeriod;
        uint256 lastUpdatedAt;
        address configManager;
    }

    // Current system configuration
    SystemConfig public currentConfig;

    // Constraints
    uint16 public constant MAX_EDUCATORS_LIMIT = 1000;
    uint16 public constant MAX_COURSES_LIMIT = 500;
    uint256 public constant MAX_MINT_LIMIT = 1_000_000 * 10**18;
    uint256 public constant MAX_COOLDOWN_PERIOD = 30 days;

    // Events with detailed logging
    event ConfigUpdated(
        address indexed authority,
        uint256 timestamp,
        string updateType
    );

    event ConfigParameterChanged(
        string parameterName,
        uint256 oldValue,
        uint256 newValue,
        address indexed updatedBy
    );

    /**
     * @dev Constructor initializes default configuration
     * @param admin Primary administrator address
     */
    constructor(address admin) {
        require(admin != address(0), "EducConfig: Invalid admin address");

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(EducRoles.ADMIN_ROLE, admin);

        // Initialize default configuration
        currentConfig = SystemConfig({
            maxEducators: 1000,
            maxCoursesPerEducator: 100,
            maxMintAmount: 1000 * 10**18,
            mintCooldownPeriod: 2 hours,
            lastUpdatedAt: block.timestamp,
            configManager: admin
        });
    }

    /**
     * @dev Updates configuration parameters with comprehensive validation
     */
    function updateConfig(
        uint16 _maxEducators,
        uint16 _maxCoursesPerEducator,
        uint256 _maxMintAmount,
        uint256 _mintCooldownPeriod
    ) 
        external 
        onlyRole(EducRoles.ADMIN_ROLE)
    {
        require(
            _maxEducators <= MAX_EDUCATORS_LIMIT && 
            _maxCoursesPerEducator <= MAX_COURSES_LIMIT &&
            _maxMintAmount <= MAX_MINT_LIMIT &&
            _mintCooldownPeriod <= MAX_COOLDOWN_PERIOD,
            "EducConfig: Invalid parameter values"
        );

        SystemConfig memory oldConfig = currentConfig;
        bool configChanged = false;

        if (_maxEducators > 0 && _maxEducators != oldConfig.maxEducators) {
            currentConfig.maxEducators = _maxEducators;
            emit ConfigParameterChanged(
                "maxEducators", 
                oldConfig.maxEducators, 
                _maxEducators, 
                msg.sender
            );
            configChanged = true;
        }

        if (_maxCoursesPerEducator > 0 && _maxCoursesPerEducator != oldConfig.maxCoursesPerEducator) {
            currentConfig.maxCoursesPerEducator = _maxCoursesPerEducator;
            emit ConfigParameterChanged(
                "maxCoursesPerEducator", 
                oldConfig.maxCoursesPerEducator, 
                _maxCoursesPerEducator, 
                msg.sender
            );
            configChanged = true;
        }

        if (_maxMintAmount > 0 && _maxMintAmount != oldConfig.maxMintAmount) {
            currentConfig.maxMintAmount = _maxMintAmount;
            emit ConfigParameterChanged(
                "maxMintAmount", 
                oldConfig.maxMintAmount, 
                _maxMintAmount, 
                msg.sender
            );
            configChanged = true;
        }

        if (_mintCooldownPeriod > 0 && _mintCooldownPeriod != oldConfig.mintCooldownPeriod) {
            currentConfig.mintCooldownPeriod = _mintCooldownPeriod;
            emit ConfigParameterChanged(
                "mintCooldownPeriod", 
                oldConfig.mintCooldownPeriod, 
                _mintCooldownPeriod, 
                msg.sender
            );
            configChanged = true;
        }

        if (configChanged) {
            currentConfig.lastUpdatedAt = block.timestamp;
            currentConfig.configManager = msg.sender;

            emit ConfigUpdated(
                msg.sender, 
                block.timestamp, 
                "SystemConfigUpdate"
            );
        }
    }

    /**
     * @dev Pauses configuration updates
     */
    function pause() external onlyRole(EducRoles.ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Unpauses configuration updates
     */
    function unpause() external onlyRole(EducRoles.ADMIN_ROLE) {
        _unpause();
    }
}