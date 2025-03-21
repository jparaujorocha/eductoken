// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title PauseTypes
 * @dev Defines type structures for the Pause module
 */
library PauseTypes {
    /**
     * @dev Parameters for setting granular pause
     */
    struct GranularPauseParams {
        uint32 functionFlags;        // Flags for functions to pause/unpause
        bool isPaused;               // Pause or unpause status
    }
    
    /**
     * @dev Records a pause action
     */
    struct PauseAction {
        address authority;           // Address that performed the pause
        uint32 flags;                // Pause flags set
        bool isGlobal;               // Whether this was a global pause
        uint256 timestamp;           // When the pause occurred
        string reason;               // Reason for the pause
    }
    
    /**
     * @dev Records an unpause action
     */
    struct UnpauseAction {
        address authority;           // Address that performed the unpause
        uint32 unsetFlags;           // Pause flags unset
        bool isGlobal;               // Whether this was a global unpause
        uint256 timestamp;           // When the unpause occurred
    }
}