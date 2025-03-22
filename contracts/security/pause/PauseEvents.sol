// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title PauseEvents
 * @dev Defines events for the Pause module
 */
library PauseEvents {
    /**
     * @dev Emitted when the system is paused globally
     * @param pauseFlags Flags indicating which functions are paused
     * @param authority Address that performed the pause
     * @param timestamp When the pause occurred
     */
    event SystemPaused(
        uint32 pauseFlags,
        address indexed authority,
        uint256 timestamp
    );

    /**
     * @dev Emitted when the system is unpaused globally
     * @param pauseFlags Flags indicating which functions were unpaused
     * @param authority Address that performed the unpause
     * @param timestamp When the unpause occurred
     */
    event SystemUnpaused(
        uint32 pauseFlags,
        address indexed authority,
        uint256 timestamp
    );

    /**
     * @dev Emitted when granular pause settings are updated
     * @param functionFlags Flags for functions that were paused/unpaused
     * @param isPaused Whether functions were paused or unpaused
     * @param authority Address that updated the pause settings
     * @param timestamp When the update occurred
     */
    event GranularPauseUpdated(
        uint32 functionFlags,
        bool isPaused,
        address indexed authority,
        uint256 timestamp
    );
    
    /**
     * @dev Emitted when a pause override is set
     * @param functionFlag Flag for the specific function
     * @param isOverridden Whether the pause is overridden
     * @param authority Address that set the override
     * @param timestamp When the override was set
     */
    event PauseOverrideSet(
        uint32 functionFlag,
        bool isOverridden,
        address indexed authority,
        uint256 timestamp
    );
}