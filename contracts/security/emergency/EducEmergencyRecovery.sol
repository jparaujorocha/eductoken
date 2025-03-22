// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../access/roles/EducRoles.sol";
import "../../config/constants/SystemConstants.sol";
import "../../interfaces/IEducEmergencyEnabled.sol";
import "./EmergencyEvents.sol";
import "./types/EmergencyTypes.sol";
import "../../governance/multisig/EducMultisig.sol";

/**
 * @title EducEmergencyRecovery
 * @dev Provides emergency recovery functions for the EducToken ecosystem
 * Includes mechanisms to recover stuck tokens and handle critical system failures
 */
contract EducEmergencyRecovery is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Multisig contract reference
    EducMultisig public multisig;
    
    // State variables
    EmergencyTypes.RecoveryConfig public config;
    EmergencyTypes.EmergencyLevel public currentEmergencyLevel;
    mapping(uint256 => EmergencyTypes.EmergencyAction) public emergencyActions;
    uint256 public emergencyActionCount;
    mapping(address => mapping(address => uint256)) public lastRecoveryTimestamp;
    
    // Emergency approvals tracking
    mapping(uint256 => mapping(address => bool)) public emergencyApprovals;
    mapping(uint256 => uint256) public emergencyApprovalCount;

    /**
     * @dev Constructor initializes the emergency recovery system
     * @param _admin Administrator address
     * @param _treasury Treasury address for recovered funds
     * @param _systemContract Main system contract address
     * @param _multisig Multisig contract address
     */
    constructor(
        address _admin,
        address _treasury,
        address _systemContract,
        address _multisig
    ) {
        _validateConstructorParams(_admin, _treasury, _systemContract, _multisig);

        // Grant admin role
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(EducRoles.ADMIN_ROLE, _admin);
        _grantRole(EducRoles.EMERGENCY_ROLE, _admin);
        
        // Set recovery config
        config = EmergencyTypes.RecoveryConfig({
            treasury: _treasury,
            systemContract: _systemContract,
            cooldownPeriod: SystemConstants.DEFAULT_COOLDOWN_PERIOD,
            approvalThreshold: SystemConstants.DEFAULT_APPROVAL_THRESHOLD
        });
        
        // Set multisig
        multisig = EducMultisig(_multisig);
        
        // No emergency by default
        currentEmergencyLevel = EmergencyTypes.EmergencyLevel.None;
    }

    /**
     * @dev Declares an emergency situation
     * @param level Emergency level
     * @param reason Reason for emergency
     */
    function declareEmergency(
        EmergencyTypes.EmergencyLevel level,
        string calldata reason
    ) 
        external
        nonReentrant
        onlyRole(EducRoles.EMERGENCY_ROLE)
    {
        _validateEmergencyDeclaration(level, reason);

        EmergencyTypes.EmergencyLevel oldLevel = currentEmergencyLevel;
        currentEmergencyLevel = level;

        uint256 actionId = ++emergencyActionCount;
        emergencyActions[actionId] = EmergencyTypes.EmergencyAction({
            id: actionId,
            level: level,
            triggeredBy: msg.sender,
            timestamp: block.timestamp,
            reason: reason,
            isActive: true,
            resolvedAt: 0,
            resolvedBy: address(0)
        });

        // Self-approve the emergency action
        emergencyApprovals[actionId][msg.sender] = true;
        emergencyApprovalCount[actionId] = 1;

        emit EmergencyEvents.EmergencyDeclared(
            actionId,
            level,
            msg.sender,
            reason,
            block.timestamp
        );
        
        emit EmergencyEvents.EmergencyLevelChanged(
            oldLevel,
            level,
            msg.sender,
            block.timestamp
        );
    }

    /**
     * @dev Approves an emergency action
     * @param actionId Emergency action ID
     */
    function approveEmergencyAction(uint256 actionId) 
        external
        nonReentrant
    {
        _validateEmergencyApproval(actionId);

        emergencyApprovals[actionId][msg.sender] = true;
        emergencyApprovalCount[actionId]++;
        
        emit EmergencyEvents.RecoveryApproved(
            actionId,
            msg.sender,
            block.timestamp
        );
    }

    /**
     * @dev Resolves an active emergency
     * @param actionId Emergency action ID
     */
    function resolveEmergency(uint256 actionId) 
        external
        nonReentrant
        onlyRole(EducRoles.EMERGENCY_ROLE)
    {
        _validateEmergencyResolution(actionId);

        EmergencyTypes.EmergencyAction storage action = emergencyActions[actionId];
        action.isActive = false;
        action.resolvedAt = block.timestamp;
        action.resolvedBy = msg.sender;
        
        EmergencyTypes.EmergencyLevel oldLevel = currentEmergencyLevel;
        currentEmergencyLevel = EmergencyTypes.EmergencyLevel.Resolved;
        
        emit EmergencyEvents.EmergencyResolved(
            actionId,
            msg.sender,
            block.timestamp
        );
        
        emit EmergencyEvents.EmergencyLevelChanged(
            oldLevel,
            EmergencyTypes.EmergencyLevel.Resolved,
            msg.sender,
            block.timestamp
        );
    }

    /**
     * @dev Recovers stuck ERC20 tokens
     * @param token Token address
     * @param from Contract address where tokens are stuck
     * @param amount Amount to recover
     */
    function recoverERC20(
        address token,
        address from,
        uint256 amount
    ) 
        external
        nonReentrant
        onlyRole(EducRoles.EMERGENCY_ROLE)
    {
        _validateTokenRecovery(token, from, amount);

        // Record recovery timestamp
        lastRecoveryTimestamp[token][from] = block.timestamp;
        
        // Create low-level call to recover tokens
        _executeTokenRecovery(token, from, amount);
        
        emit EmergencyEvents.TokensRecovered(
            token,
            from,
            amount,
            config.treasury,
            msg.sender,
            block.timestamp
        );
    }

    /**
     * @dev Recovers native tokens (ETH)
     * @param from Contract address where ETH is stuck
     * @param amount Amount to recover
     */
    function recoverETH(
        address from,
        uint256 amount
    ) 
        external
        nonReentrant
        onlyRole(EducRoles.EMERGENCY_ROLE)
    {
        _validateETHRecovery(from, amount);

        // Record recovery timestamp
        lastRecoveryTimestamp[SystemConstants.ETH_PSEUDO_ADDRESS][from] = block.timestamp;
        
        // Try to recover ETH
        _executeETHRecovery(from, amount);
        
        emit EmergencyEvents.TokensRecovered(
            SystemConstants.ETH_PSEUDO_ADDRESS,
            from,
            amount,
            config.treasury,
            msg.sender,
            block.timestamp
        );
    }

    /**
     * @dev Updates the recovery configuration
     * @param _treasury New treasury address
     * @param _systemContract New system contract address
     * @param _cooldownPeriod New cooldown period
     * @param _approvalThreshold New approval threshold
     */
    function updateConfig(
        address _treasury,
        address _systemContract,
        uint256 _cooldownPeriod,
        uint256 _approvalThreshold
    ) 
        external
        onlyRole(EducRoles.ADMIN_ROLE)
    {
        _validateConfigUpdate(_treasury, _systemContract, _cooldownPeriod, _approvalThreshold);

        address oldTreasury = config.treasury;
        address oldSystemContract = config.systemContract;
        uint256 oldCooldown = config.cooldownPeriod;
        uint256 oldThreshold = config.approvalThreshold;
        
        config.treasury = _treasury;
        config.systemContract = _systemContract;
        config.cooldownPeriod = _cooldownPeriod;
        config.approvalThreshold = _approvalThreshold;
        
        emit EmergencyEvents.ConfigUpdated(
            oldTreasury,
            _treasury,
            oldSystemContract,
            _systemContract,
            oldCooldown,
            _cooldownPeriod,
            oldThreshold,
            _approvalThreshold,
            block.timestamp
        );
    }

    /**
     * @dev Manually set emergency level (only for downgrading)
     * @param newLevel New emergency level
     */
    function setEmergencyLevel(EmergencyTypes.EmergencyLevel newLevel) 
        external
        onlyRole(EducRoles.EMERGENCY_ROLE)
    {
        _validateEmergencyLevelDowngrade(newLevel);

        EmergencyTypes.EmergencyLevel oldLevel = currentEmergencyLevel;
        currentEmergencyLevel = newLevel;
        
        emit EmergencyEvents.EmergencyLevelChanged(
            oldLevel,
            newLevel,
            msg.sender,
            block.timestamp
        );
    }

    /**
     * @dev Gets the details of an emergency action
     * @param actionId Emergency action ID
     * @return id ID of the emergency action
     * @return level Emergency level
     * @return triggeredBy Address that triggered the emergency
     * @return timestamp Timestamp when the emergency was triggered
     * @return reason Reason for the emergency
     * @return isActive Whether the emergency is active
     * @return resolvedAt Timestamp when the emergency was resolved (0 if not resolved)
     * @return resolvedBy Address that resolved the emergency (address(0) if not resolved)
     * @return approvals Number of approvals for the emergency action
     */
    function getEmergencyAction(uint256 actionId) 
        external 
        view 
        returns (
            uint256 id,
            EmergencyTypes.EmergencyLevel level,
            address triggeredBy,
            uint256 timestamp,
            string memory reason,
            bool isActive,
            uint256 resolvedAt,
            address resolvedBy,
            uint256 approvals
        ) 
    {
        require(actionId > 0 && actionId <= emergencyActionCount, "EducEmergencyRecovery: Invalid action ID");
        
        EmergencyTypes.EmergencyAction storage action = emergencyActions[actionId];
        
        return (
            action.id,
            action.level,
            action.triggeredBy,
            action.timestamp,
            action.reason,
            action.isActive,
            action.resolvedAt,
            action.resolvedBy,
            emergencyApprovalCount[actionId]
        );
    }

    /**
     * @dev Checks if an address has approved an emergency action
     * @param actionId Emergency action ID
     * @param approver Approver address
     * @return Boolean indicating approval status
     */
    function hasApproved(uint256 actionId, address approver) 
        external 
        view 
        returns (bool) 
    {
        return emergencyApprovals[actionId][approver];
    }

    /**
     * @dev Gets active emergency actions
     * @return Array of active emergency action IDs
     */
    function getActiveEmergencyActions() 
        external 
        view 
        returns (uint256[] memory) 
    {
        uint256 activeCount = 0;
        
        // Count active emergencies
        for (uint256 i = 1; i <= emergencyActionCount; i++) {
            if (emergencyActions[i].isActive) {
                activeCount++;
            }
        }
        
        // Create result array
        uint256[] memory result = new uint256[](activeCount);
        uint256 index = 0;
        
        // Fill result array
        for (uint256 i = 1; i <= emergencyActionCount; i++) {
            if (emergencyActions[i].isActive) {
                result[index++] = i;
            }
        }
        
        return result;
    }

    // Private methods for validation and execution

    function _validateConstructorParams(
        address _admin,
        address _treasury,
        address _systemContract,
        address _multisig
    ) private pure {
        require(_admin != address(0), "EducEmergencyRecovery: Invalid admin address");
        require(_treasury != address(0), "EducEmergencyRecovery: Invalid treasury address");
        require(_systemContract != address(0), "EducEmergencyRecovery: Invalid system contract address");
        require(_multisig != address(0), "EducEmergencyRecovery: Invalid multisig address");
    }

    function _validateEmergencyDeclaration(
        EmergencyTypes.EmergencyLevel level,
        string calldata reason
    ) private pure {
        require(level != EmergencyTypes.EmergencyLevel.None && level != EmergencyTypes.EmergencyLevel.Resolved, "EducEmergencyRecovery: Invalid emergency level");
        require(bytes(reason).length > 0 && bytes(reason).length <= SystemConstants.MAX_DESCRIPTION_LENGTH, "EducEmergencyRecovery: Invalid reason length");
    }

    function _validateEmergencyApproval(uint256 actionId) private view {
        require(multisig.isSigner(msg.sender), "EducEmergencyRecovery: Not a multisig signer");
        require(actionId > 0 && actionId <= emergencyActionCount, "EducEmergencyRecovery: Invalid action ID");
        require(emergencyActions[actionId].isActive, "EducEmergencyRecovery: Action not active");
        require(!emergencyApprovals[actionId][msg.sender], "EducEmergencyRecovery: Already approved");
    }

    function _validateEmergencyResolution(uint256 actionId) private view {
        require(actionId > 0 && actionId <= emergencyActionCount, "EducEmergencyRecovery: Invalid action ID");
        require(emergencyActions[actionId].isActive, "EducEmergencyRecovery: Action not active");
        require(emergencyApprovalCount[actionId] >= config.approvalThreshold, "EducEmergencyRecovery: Insufficient approvals");
    }

    function _validateTokenRecovery(
        address token,
        address from,
        uint256 amount
    ) private view {
        require(token != address(0), "EducEmergencyRecovery: Invalid token address");
        require(from != address(0), "EducEmergencyRecovery: Invalid from address");
        require(amount > 0, "EducEmergencyRecovery: Amount must be positive");
        require(
            currentEmergencyLevel == EmergencyTypes.EmergencyLevel.Level2 || 
            currentEmergencyLevel == EmergencyTypes.EmergencyLevel.Level3,
            "EducEmergencyRecovery: Emergency level not high enough"
        );
        require(
            block.timestamp > lastRecoveryTimestamp[token][from] + config.cooldownPeriod,
            "EducEmergencyRecovery: Cooldown period not elapsed"
        );
        require(_hasApprovedEmergency(), "EducEmergencyRecovery: No approved emergency");
    }

    function _validateETHRecovery(
        address from,
        uint256 amount
    ) private view {
        require(from != address(0), "EducEmergencyRecovery: Invalid from address");
        require(amount > 0, "EducEmergencyRecovery: Amount must be positive");
        require(
            currentEmergencyLevel == EmergencyTypes.EmergencyLevel.Level3,
            "EducEmergencyRecovery: Emergency level not high enough"
        );
        require(
            block.timestamp > lastRecoveryTimestamp[SystemConstants.ETH_PSEUDO_ADDRESS][from] + config.cooldownPeriod,
            "EducEmergencyRecovery: Cooldown period not elapsed"
        );
        require(_hasApprovedEmergency(), "EducEmergencyRecovery: No approved emergency");
    }

    function _validateConfigUpdate(
        address _treasury,
        address _systemContract,
        uint256 _cooldownPeriod,
        uint256 _approvalThreshold
    ) private pure {
        require(_treasury != address(0), "EducEmergencyRecovery: Invalid treasury address");
        require(_systemContract != address(0), "EducEmergencyRecovery: Invalid system contract address");
        require(_cooldownPeriod > 0, "EducEmergencyRecovery: Invalid cooldown period");
        require(_approvalThreshold > 0, "EducEmergencyRecovery: Invalid approval threshold");
    }

    function _validateEmergencyLevelDowngrade(EmergencyTypes.EmergencyLevel newLevel) private view {
        require(
            uint8(newLevel) <= uint8(currentEmergencyLevel), 
            "EducEmergencyRecovery: Cannot escalate emergency level"
        );
    }

    function _hasApprovedEmergency() private view returns (bool) {
        for (uint256 i = 1; i <= emergencyActionCount; i++) {
            if (emergencyActions[i].isActive && emergencyApprovalCount[i] >= config.approvalThreshold) {
                return true;
            }
        }
        return false;
    }

    function _executeTokenRecovery(
        address token,
        address from,
        uint256 amount
    ) private {
        (bool success, bytes memory data) = from.call(
            abi.encodeWithSelector(
                IERC20(token).transfer.selector,
                config.treasury,
                amount
            )
        );
        
        if (!success) {
            bytes memory callData = abi.encodeWithSelector(
                bytes4(keccak256("executeEmergencyWithdrawal(address,uint256)")),
                token,
                amount
            );
            
            (success, data) = from.call(callData);
            
            require(success, "EducEmergencyRecovery: Recovery failed");
        }
    }

    function _executeETHRecovery(
        address from,
        uint256 amount
    ) private {
        bytes memory callData = abi.encodeWithSelector(
            bytes4(keccak256("executeEmergencyETHWithdrawal(uint256)")),
            amount
        );
        
        (bool success, ) = from.call(callData);
        require(success, "EducEmergencyRecovery: ETH recovery failed");
    }
}