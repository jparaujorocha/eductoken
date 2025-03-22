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
    uint32 public pauseFlags;
    address public lastPauseAuthority;
    
    mapping(address => mapping(uint32 => bool)) private pauseOverrides;
    
    PauseTypes.PauseAction[] private pauseActions;
    PauseTypes.UnpauseAction[] private unpauseActions;

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

    constructor(address admin) {
        require(admin != address(0), "EducPause: Invalid admin address");
        _setupInitialRoles(admin);
        pauseFlags = 0;
    }
    
    function _setupInitialRoles(address admin) private {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(EducRoles.ADMIN_ROLE, admin);
        _grantRole(EducRoles.EMERGENCY_ROLE, admin);
    }

    function setEmergencyPause(bool pauseStatus) 
        external 
        override 
        onlyEmergencyRole 
    {
        _setEmergencyPause(pauseStatus, "");
    }
    
    function _setEmergencyPause(bool pauseStatus, string memory reason) private {
        lastPauseAuthority = msg.sender;
        if (pauseStatus) {
            _pauseSystem(reason);
        } else {
            _unpauseSystem();
        }
    }

    function _pauseSystem(string memory reason) private {
        _pause();
        pauseFlags = SystemConstants.PAUSE_FLAG_ALL;
        _recordPauseAction(pauseFlags, true, reason);
        emit PauseEvents.SystemPaused(pauseFlags, msg.sender, block.timestamp);
    }

    function _unpauseSystem() private {
        _unpause();
        _recordUnpauseAction(pauseFlags, true);
        pauseFlags = 0;
        emit PauseEvents.SystemUnpaused(pauseFlags, msg.sender, block.timestamp);
    }

    function setGranularPause(PauseTypes.GranularPauseParams calldata params)
        external
        override
        onlyEmergencyRole
    {
        _setGranularPause(params.functionFlags, params.isPaused);
    }

    function setGranularPauseLegacy(uint32 functionFlags, bool isPausedGranular) 
        external 
        override
        onlyEmergencyRole 
    {
        _setGranularPause(functionFlags, isPausedGranular);
    }
    
    function _setGranularPause(uint32 functionFlags, bool isGranularPause) private {
        lastPauseAuthority = msg.sender;
        if (isGranularPause) {
            _applyGranularPause(functionFlags);
        } else {
            _removeGranularPause(functionFlags);
        }
        emit PauseEvents.GranularPauseUpdated(pauseFlags, isGranularPause, msg.sender, block.timestamp);
    }

    function _applyGranularPause(uint32 functionFlags) private {
        pauseFlags |= functionFlags;
        _recordPauseAction(functionFlags, false, "");
        if (!paused()) {
            _pause();
        }
    }

    function _removeGranularPause(uint32 functionFlags) private {
        _recordUnpauseAction(functionFlags & pauseFlags, false);
        pauseFlags &= ~functionFlags;
        if (pauseFlags == 0 && paused()) {
            _unpause();
        }
    }

    function setPauseOverride(address address_, uint32 functionFlag, bool isOverridden)
        external
        override
        onlyAdminRole
    {
        require(address_ != address(0), "EducPause: Cannot override zero address");
        pauseOverrides[address_][functionFlag] = isOverridden;
        emit PauseEvents.PauseOverrideSet(functionFlag, isOverridden, msg.sender, block.timestamp);
    }

    function isFunctionPaused(uint32 functionFlag) 
        external 
        view 
        override
        returns (bool isFunctionPause) 
    {
        return paused() && ((pauseFlags & functionFlag) != 0);
    }
    
    function isFunctionPausedForAddress(address address_, uint32 functionFlag)
        external
        view
        override
        returns (bool isPausedForAddress)
    {
        bool functionallyPaused = paused() && ((pauseFlags & functionFlag) != 0);
        if (functionallyPaused && pauseOverrides[address_][functionFlag]) {
            return false;
        }
        return functionallyPaused;
    }

    function getCurrentPauseFlags() 
        external 
        view 
        override
        returns (uint32 flags) 
    {
        return pauseFlags;
    }
    
    function getLastPauseAuthority()
        external
        view
        override
        returns (address authority)
    {
        return lastPauseAuthority;
    }
    
    function isPaused()
        external
        view
        override
        returns (bool)
    {
        return paused();
    }
    
    function getPauseActionCount() external view returns (uint256 count) {
        return pauseActions.length;
    }
    
    function getUnpauseActionCount() external view returns (uint256 count) {
        return unpauseActions.length;
    }
    
    function getPauseAction(uint256 index) 
        external 
        view 
        returns (PauseTypes.PauseAction memory action) 
    {
        require(index < pauseActions.length, "EducPause: Index out of bounds");
        return pauseActions[index];
    }
    
    function getUnpauseAction(uint256 index)
        external
        view
        returns (PauseTypes.UnpauseAction memory action)
    {
        require(index < unpauseActions.length, "EducPause: Index out of bounds");
        return unpauseActions[index];
    }

    function _recordPauseAction(uint32 flags, bool isGlobal, string memory reason) private {
        pauseActions.push(PauseTypes.PauseAction({
            authority: msg.sender,
            flags: flags,
            isGlobal: isGlobal,
            timestamp: block.timestamp,
            reason: reason
        }));
    }

    function _recordUnpauseAction(uint32 flags, bool isGlobal) private {
        unpauseActions.push(PauseTypes.UnpauseAction({
            authority: msg.sender,
            unsetFlags: flags,
            isGlobal: isGlobal,
            timestamp: block.timestamp
        }));
    }
}