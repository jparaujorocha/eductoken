// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "../../access/roles/EducRoles.sol";
import "../../config/constants/SystemConstants.sol";
import "../../interfaces/IEducPause.sol";
import "./PauseEvents.sol";
import "./types/PauseTypes.sol";

/**
 * @title EducPause
 * @dev Advanced granular pause mechanism for the educational ecosystem
 */
contract EducPause is AccessControl, Pausable, IEducPause {
    // Current pause state tracking
    uint32 public pauseFlags;
    address public lastPauseAuthority;
    
    // Pause overrides for specific addresses
    mapping(address => mapping(uint32 => bool)) private pauseOverrides;
    
    // Pause action history
    PauseTypes.PauseAction[] private pauseActions;
    PauseTypes.UnpauseAction[] private unpauseActions;

    // Modifiers
    modifier onlyEmergencyRole() {
        require(hasRole(EducRoles.EMERGENCY_ROLE, msg.sender), 
            "EducPause: caller does not have emergency role");
        _;
    }
    
    modifier onlyAdminRole() {
        require(hasRole(EducRoles.ADMIN_ROLE, msg.sender),
            "EducPause: caller does not have admin role");
        _;
    }

    /**
     * @dev Constructor sets up initial admin and emergency roles
     * @param admin Administrator address
     */
    constructor(address admin) {
        require(admin != address(0), "EducPause: Invalid admin address");

        _setupInitialRoles(admin);
        pauseFlags = 0;  // Initially no functions paused
    }
    
    /**
     * @dev Sets up initial roles for the admin
     * @param admin Address to receive admin and emergency roles
     */
    function _setupInitialRoles(address admin) private {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(EducRoles.ADMIN_ROLE, admin);
        _grantRole(EducRoles.EMERGENCY_ROLE, admin);
    }

    /**
     * @dev Sets emergency pause across the system
     * @param pauseStatus Global pause status (true to pause, false to unpause)
     */
    function setEmergencyPause(bool pauseStatus) 
        external 
        override 
        onlyEmergencyRole 
    {
        _setEmergencyPause(pauseStatus, "");
    }
    
    /**
     * @dev Internal implementation of emergency pause
     * @param pauseStatus Global pause status
     * @param reason Optional reason for the pause (empty string if none)
     */
    function _setEmergencyPause(bool pauseStatus, string memory reason) private {
        lastPauseAuthority = msg.sender;

        if (pauseStatus) {
            _pause();
            pauseFlags = SystemConstants.PAUSE_FLAG_ALL;
            
            // Record pause action
            pauseActions.push(PauseTypes.PauseAction({
                authority: msg.sender,
                flags: pauseFlags,
                isGlobal: true,
                timestamp: block.timestamp,
                reason: reason
            }));
            
            emit PauseEvents.SystemPaused(
                pauseFlags, 
                msg.sender, 
                block.timestamp
            );
        } else {
            _unpause();
            
            // Record unpause action
            unpauseActions.push(PauseTypes.UnpauseAction({
                authority: msg.sender,
                unsetFlags: pauseFlags,
                isGlobal: true,
                timestamp: block.timestamp
            }));
            
            pauseFlags = 0;
            
            emit PauseEvents.SystemUnpaused(
                pauseFlags, 
                msg.sender, 
                block.timestamp
            );
        }
    }

    /**
     * @dev Sets granular pause with structured params
     * @param params Structured parameters (function flags and pause status)
     */
    function setGranularPause(PauseTypes.GranularPauseParams calldata params)
        external
        override
        onlyEmergencyRole
    {
        _setGranularPause(params.functionFlags, params.isPaused);
    }

    /**
     * @dev Legacy method for compatibility - sets granular pause
     * @param functionFlags Bitmask of functions to pause/unpause
     * @param isPaused Pause or unpause status
     */
    function setGranularPause(uint32 functionFlags, bool isPaused) 
        external 
        override
        onlyEmergencyRole 
    {
        _setGranularPause(functionFlags, isPaused);
    }
    
    /**
     * @dev Internal implementation of granular pause
     * @param functionFlags Bitmask of functions to pause/unpause
     * @param isGranularPaused Pause or unpause status
     */
    function _setGranularPause(uint32 functionFlags, bool isGranularPaused) private {
        lastPauseAuthority = msg.sender;

        if (isGranularPaused) {
            pauseFlags |= functionFlags;
            
            // Record pause action
            pauseActions.push(PauseTypes.PauseAction({
                authority: msg.sender,
                flags: functionFlags,
                isGlobal: false,
                timestamp: block.timestamp,
                reason: "" // No reason for granular pause
            }));
            
            // Ensure system is paused if any flag is set
            if (!paused()) {
                _pause();
            }
        } else {
            // Record unpause action
            unpauseActions.push(PauseTypes.UnpauseAction({
                authority: msg.sender,
                unsetFlags: functionFlags & pauseFlags, // Only flags that were set
                isGlobal: false,
                timestamp: block.timestamp
            }));
            
            pauseFlags &= ~functionFlags;
            
            // Unpause system if no flags remain
            if (pauseFlags == 0 && paused()) {
                _unpause();
            }
        }

        emit PauseEvents.GranularPauseUpdated(
            pauseFlags, 
            isGranularPaused, 
            msg.sender, 
            block.timestamp
        );
    }
    
    /**
     * @dev Sets a pause override for specific addresses
     * @param address_ Address to set override for
     * @param functionFlag Function flag to override
     * @param isOverridden Whether the pause is overridden
     */
    function setPauseOverride(address address_, uint32 functionFlag, bool isOverridden)
        external
        override
        onlyAdminRole
    {
        require(address_ != address(0), "EducPause: Cannot override zero address");
        
        pauseOverrides[address_][functionFlag] = isOverridden;
        
        emit PauseEvents.PauseOverrideSet(
            functionFlag,
            isOverridden,
            msg.sender,
            block.timestamp
        );
    }

    /**
     * @dev Checks if a specific function is currently paused
     * @param functionFlag Function flag to check
     * @return isFunctionPaused Boolean indicating pause status
     */
    function isFunctionPaused(uint32 functionFlag) 
        external 
        view 
        override
        returns (bool isFunctionPaused) 
    {
        return paused() && ((pauseFlags & functionFlag) != 0);
    }
    
    /**
     * @dev Checks if a specific function is paused for an address
     * @param address_ Address to check
     * @param functionFlag Function flag to check
     * @return isFunctionPausedForAddress Boolean indicating pause status for the address
     */
    function isFunctionPausedForAddress(address address_, uint32 functionFlag)
        external
        view
        override
        returns (bool isFunctionPausedForAddress)
    {
        bool functionallyPaused = paused() && ((pauseFlags & functionFlag) != 0);
        
        // Check if there's an override for this address and function
        if (functionallyPaused && pauseOverrides[address_][functionFlag]) {
            return false; // Override bypasses the pause
        }
        
        return functionallyPaused;
    }

    /**
     * @dev Gets the current pause flags
     * @return flags Current pause flags
     */
    function getCurrentPauseFlags() 
        external 
        view 
        override
        returns (uint32 flags) 
    {
        return pauseFlags;
    }
    
    /**
     * @dev Gets the address of the last pause authority
     * @return authority Address that last changed pause status
     */
    function getLastPauseAuthority()
        external
        view
        override
        returns (address authority)
    {
        return lastPauseAuthority;
    }
    
    /**
     * @dev Gets whether the system is currently paused
     * @return isPaused Boolean indicating global pause status
     */
    function isPaused()
        external
        view
        override
        returns (bool)
    {
        return paused();
    }
    
    /**
     * @dev Gets the number of pause actions recorded
     * @return count Number of pause actions
     */
    function getPauseActionCount() external view returns (uint256 count) {
        return pauseActions.length;
    }
    
    /**
     * @dev Gets the number of unpause actions recorded
     * @return count Number of unpause actions
     */
    function getUnpauseActionCount() external view returns (uint256 count) {
        return unpauseActions.length;
    }
    
    /**
     * @dev Gets details of a specific pause action
     * @param index Index of the pause action
     * @return action The pause action details
     */
    function getPauseAction(uint256 index) 
        external 
        view 
        returns (PauseTypes.PauseAction memory action) 
    {
        require(index < pauseActions.length, "EducPause: Index out of bounds");
        return pauseActions[index];
    }
    
    /**
     * @dev Gets details of a specific unpause action
     * @param index Index of the unpause action
     * @return action The unpause action details
     */
    function getUnpauseAction(uint256 index)
        external
        view
        returns (PauseTypes.UnpauseAction memory action)
    {
        require(index < unpauseActions.length, "EducPause: Index out of bounds");
        return unpauseActions[index];
    }
}