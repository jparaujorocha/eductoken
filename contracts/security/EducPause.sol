// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "../access/EducRoles.sol";

/**
 * @title EducPause
 * @dev Advanced granular pause mechanism for the educational ecosystem
 */
contract EducPause is AccessControl, Pausable {
    // Granular pause flags
    uint32 public constant PAUSE_FLAG_MINT = 1 << 0;         // 1
    uint32 public constant PAUSE_FLAG_TRANSFER = 1 << 1;     // 2
    uint32 public constant PAUSE_FLAG_BURN = 1 << 2;         // 4
    uint32 public constant PAUSE_FLAG_REGISTER = 1 << 3;     // 8
    uint32 public constant PAUSE_FLAG_COURSE = 1 << 4;       // 16
    uint32 public constant PAUSE_FLAG_EDUCATOR = 1 << 5;     // 32
    uint32 public constant PAUSE_FLAG_STUDENT = 1 << 6;      // 64
    uint32 public constant PAUSE_FLAG_ALL = 0xFFFFFFFF;      // All flags

    // Current pause state tracking
    uint32 public pauseFlags;
    address public lastPauseAuthority;

    // Events with comprehensive logging
    event SystemPaused(
        uint32 pauseFlags,
        address indexed authority,
        uint256 timestamp
    );

    event SystemUnpaused(
        uint32 pauseFlags,
        address indexed authority,
        uint256 timestamp
    );

    event GranularPauseUpdated(
        uint32 pauseFlags,
        bool isPaused,
        address indexed authority,
        uint256 timestamp
    );

    /**
     * @dev Constructor sets up initial admin and emergency roles
     * @param admin Administrator address
     */
    constructor(address admin) {
        require(admin != address(0), "EducPause: Invalid admin address");

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(EducRoles.ADMIN_ROLE, admin);
        _grantRole(EducRoles.EMERGENCY_ROLE, admin);

        pauseFlags = 0;  // Initially no functions paused
    }

    /**
     * @dev Global emergency pause mechanism
     * @param pauseStatus Global pause status
     */
    function setEmergencyPause(bool pauseStatus) 
        external 
        onlyRole(EducRoles.EMERGENCY_ROLE) 
    {
        lastPauseAuthority = msg.sender;

        if (pauseStatus) {
            _pause();
            pauseFlags = PAUSE_FLAG_ALL;
            
            emit SystemPaused(
                pauseFlags, 
                msg.sender, 
                block.timestamp
            );
        } else {
            _unpause();
            pauseFlags = 0;
            
            emit SystemUnpaused(
                pauseFlags, 
                msg.sender, 
                block.timestamp
            );
        }
    }

    /**
     * @dev Sets granular pause for specific system functions
     * @param functionFlags Bitmask of functions to pause/unpause
     * @param isPaused Pause or unpause status
     */
    function setGranularPause(
        uint32 functionFlags, 
        bool isPaused
    ) 
        external 
        onlyRole(EducRoles.EMERGENCY_ROLE) 
    {
        lastPauseAuthority = msg.sender;

        if (isPaused) {
            pauseFlags |= functionFlags;
            
            // Ensure system is paused if any flag is set
            if (!paused()) {
                _pause();
            }
        } else {
            pauseFlags &= ~functionFlags;
            
            // Unpause system if no flags remain
            if (pauseFlags == 0 && paused()) {
                _unpause();
            }
        }

        emit GranularPauseUpdated(
            pauseFlags, 
            isPaused, 
            msg.sender, 
            block.timestamp
        );
    }

    /**
     * @dev Checks if a specific function is currently paused
     * @param functionFlag Function flag to check
     * @return Boolean indicating pause status
     */
    function isFunctionPaused(uint32 functionFlag) 
        external 
        view 
        returns (bool) 
    {
        return paused() && ((pauseFlags & functionFlag) != 0);
    }

    /**
     * @dev Retrieves current pause flags
     * @return Current pause flags
     */
    function getCurrentPauseFlags() 
        external 
        view 
        returns (uint32) 
    {
        return pauseFlags;
    }
}