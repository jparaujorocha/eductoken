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

        _initializeDefaultConfig(admin);
    }

    function _initializeDefaultConfig(address admin) private {
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
        _validateConfigParams(_maxEducators, _maxCoursesPerEducator, _maxMintAmount, _mintCooldownPeriod);
        _updateConfigParams(_maxEducators, _maxCoursesPerEducator, _maxMintAmount, _mintCooldownPeriod);
    }

    function _validateConfigParams(
        uint16 _maxEducators,
        uint16 _maxCoursesPerEducator,
        uint256 _maxMintAmount,
        uint256 _mintCooldownPeriod
    ) 
        private 
        pure 
    {
        require(
            _maxEducators <= MAX_EDUCATORS_LIMIT && 
            _maxCoursesPerEducator <= MAX_COURSES_LIMIT &&
            _maxMintAmount <= MAX_MINT_LIMIT &&
            _mintCooldownPeriod <= MAX_COOLDOWN_PERIOD,
            "EducConfig: Invalid parameter values"
        );
    }

    function _updateConfigParams(
        uint16 _maxEducators,
        uint16 _maxCoursesPerEducator,
        uint256 _maxMintAmount,
        uint256 _mintCooldownPeriod
    ) 
        private 
    {
        SystemConfig memory oldConfig = currentConfig;
        bool configChanged = false;

        configChanged = _updateMaxEducators(_maxEducators, oldConfig) || configChanged;
        configChanged = _updateMaxCoursesPerEducator(_maxCoursesPerEducator, oldConfig) || configChanged;
        configChanged = _updateMaxMintAmount(_maxMintAmount, oldConfig) || configChanged;
        configChanged = _updateMintCooldownPeriod(_mintCooldownPeriod, oldConfig) || configChanged;

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

    function _updateMaxEducators(uint16 _maxEducators, SystemConfig memory oldConfig) private returns (bool) {
        if (_maxEducators > 0 && _maxEducators != oldConfig.maxEducators) {
            currentConfig.maxEducators = _maxEducators;
            emit ConfigParameterChanged(
                "maxEducators", 
                oldConfig.maxEducators, 
                _maxEducators, 
                msg.sender
            );
            return true;
        }
        return false;
    }

    function _updateMaxCoursesPerEducator(uint16 _maxCoursesPerEducator, SystemConfig memory oldConfig) private returns (bool) {
        if (_maxCoursesPerEducator > 0 && _maxCoursesPerEducator != oldConfig.maxCoursesPerEducator) {
            currentConfig.maxCoursesPerEducator = _maxCoursesPerEducator;
            emit ConfigParameterChanged(
                "maxCoursesPerEducator", 
                oldConfig.maxCoursesPerEducator, 
                _maxCoursesPerEducator, 
                msg.sender
            );
            return true;
        }
        return false;
    }

    function _updateMaxMintAmount(uint256 _maxMintAmount, SystemConfig memory oldConfig) private returns (bool) {
        if (_maxMintAmount > 0 && _maxMintAmount != oldConfig.maxMintAmount) {
            currentConfig.maxMintAmount = _maxMintAmount;
            emit ConfigParameterChanged(
                "maxMintAmount", 
                oldConfig.maxMintAmount, 
                _maxMintAmount, 
                msg.sender
            );
            return true;
        }
        return false;
    }

    function _updateMintCooldownPeriod(uint256 _mintCooldownPeriod, SystemConfig memory oldConfig) private returns (bool) {
        if (_mintCooldownPeriod > 0 && _mintCooldownPeriod != oldConfig.mintCooldownPeriod) {
            currentConfig.mintCooldownPeriod = _mintCooldownPeriod;
            emit ConfigParameterChanged(
                "mintCooldownPeriod", 
                oldConfig.mintCooldownPeriod, 
                _mintCooldownPeriod, 
                msg.sender
            );
            return true;
        }
        return false;
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