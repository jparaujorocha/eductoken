// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "../access/EducRoles.sol";

/**
 * @title EducPause
 * @dev Manages granular pause functionality for the EducLearning system
 */
contract EducPause is AccessControl, Pausable {
    // Function flags for granular pausing
    uint32 public constant PAUSE_FLAG_MINT = 1 << 0;
    uint32 public constant PAUSE_FLAG_TRANSFER = 1 << 1;
    uint32 public constant PAUSE_FLAG_BURN = 1 << 2;
    uint32 public constant PAUSE_FLAG_REGISTER = 1 << 3;
    uint32 public constant PAUSE_FLAG_COURSE = 1 << 4;
    uint32 public constant PAUSE_FLAG_ALL = 0xFFFFFFFF;

    // Current pause flags
    uint32 public pauseFlags;

    // Events
    event ProgramStatusChanged(
        bool paused,
        address indexed authority,
        uint256 timestamp
    );

    event GranularPauseChanged(
        uint32 pauseFlags,
        address indexed authority,
        uint256 timestamp
    );

    /**
     * @dev Constructor that sets up admin and emergency roles
     * @param admin The address that will be granted admin roles
     */
    constructor(address admin) {
        require(admin != address(0), "EducPause: admin cannot be zero address");


    _grantRole(DEFAULT_ADMIN_ROLE, admin);
    _grantRole(EducRoles.ADMIN_ROLE, admin);
    _grantRole(EducRoles.EMERGENCY_ROLE, admin);

        pauseFlags = 0; // No functions paused initially
    }

    /**
     * @dev Pauses or unpauses the entire system
     * @param paused Whether to pause (true) or unpause (false)
     */
    function setEmergencyPause(bool paused) 
        external 
        onlyRole(EducRoles.EMERGENCY_ROLE) 
    {
        if (paused) {
            _pause();
            pauseFlags = PAUSE_FLAG_ALL;
        } else {
            _unpause();
            pauseFlags = 0;
        }

        emit ProgramStatusChanged(paused, msg.sender, block.timestamp);
    }

    /**
     * @dev Sets or clears specific pause flags
     * @param functionFlags Bitmask of functions to modify
     * @param setFlags Whether to set (true) or clear (false) the flags
     */
    function setGranularPause(uint32 functionFlags, bool setFlags) 
        external 
        onlyRole(EducRoles.EMERGENCY_ROLE) 
    {
        if (setFlags) {
            pauseFlags |= functionFlags;
            if (pauseFlags != 0 && !paused()) {
                _pause();
            }
        } else {
            pauseFlags &= ~functionFlags;
            if (pauseFlags == 0 && paused()) {
                _unpause();
            }
        }

        emit GranularPauseChanged(pauseFlags, msg.sender, block.timestamp);
    }

    /**
     * @dev Checks if a specific function is paused
     * @param functionFlag Flag to check
     * @return bool True if the function is paused
     */
    function isFunctionPaused(uint32 functionFlag) external view returns (bool) {
        return paused() && ((pauseFlags & functionFlag) != 0);
    }
}