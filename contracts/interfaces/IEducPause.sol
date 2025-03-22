// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../security/pause/types/PauseTypes.sol";

/**
 * @title IEducPause
 * @dev Interface for the EducPause contract
 */
interface IEducPause {
    /**
     * @dev Sets emergency pause across the system
     * @param pauseStatus Global pause status (true to pause, false to unpause)
     */
    function setEmergencyPause(bool pauseStatus) external;
    
    /**
     * @dev Sets granular pause for specific system functions
     * @param params Structured parameters (function flags and pause status)
     */
    function setGranularPause(PauseTypes.GranularPauseParams calldata params) external;
    
    /**
     * @dev Legacy method for compatibility - sets granular pause
     * @param functionFlags Bitmask of functions to pause/unpause
     * @param isPausedGranular Pause or unpause status
     */
    function setGranularPauseLegacy(uint32 functionFlags, bool isPausedGranular) external;
    
    /**
     * @dev Sets a pause override for specific addresses
     * @param address_ Address to set override for
     * @param functionFlag Function flag to override
     * @param isOverridden Whether the pause is overridden
     */
    function setPauseOverride(address address_, uint32 functionFlag, bool isOverridden) external;
    
    /**
     * @dev Checks if a specific function is currently paused
     * @param functionFlag Function flag to check
     * @return isFunctionPause Boolean indicating pause status
     */
    function isFunctionPaused(uint32 functionFlag) external view returns (bool isFunctionPause);
    
    /**
     * @dev Checks if a specific function is paused for an address
     * @param address_ Address to check
     * @param functionFlag Function flag to check
     * @return isPausedForAddress Boolean indicating pause status for the address
     */
    function isFunctionPausedForAddress(address address_, uint32 functionFlag) 
        external 
        view 
        returns (bool isPausedForAddress);
    
    /**
     * @dev Gets the current pause flags
     * @return flags Current pause flags
     */
    function getCurrentPauseFlags() external view returns (uint32 flags);
    
    /**
     * @dev Gets the address of the last pause authority
     * @return authority Address that last changed pause status
     */
    function getLastPauseAuthority() external view returns (address authority);
    
    /**
     * @dev Gets whether the system is currently paused
     * @return isPaused Boolean indicating global pause status
     */
    function isPaused() external view returns (bool isPaused);
}