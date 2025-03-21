// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../../access/roles/EducRoles.sol";
import "../../config/constants/SystemConstants.sol";
import "../../interfaces/IEducEmergencyEnabled.sol";
import "./EmergencyEvents.sol";
import "./types/EmergencyTypes.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../governance/multisig/EducMultisig.sol";



/**
 * @title EducEmergencyRecovery
 * @dev Provides emergency recovery functions for the EducToken ecosystem
 * Includes mechanisms to recover stuck tokens and handle critical system failures
 */
contract EducEmergencyRecovery is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Emergency recovery states
    enum EmergencyLevel {
        None,       // No emergency
        Level1,     // Minor issue, requires monitoring
        Level2,     // Moderate issue, requires restrictions
        Level3,     // Critical issue, emergency mode activated
        Resolved    // Emergency resolved
    }

    // Emergency action tracking
    struct EmergencyAction {
        uint256 id;
        EmergencyLevel level;
        address triggeredBy;
        uint256 timestamp;
        string reason;
        bool isActive;
        uint256 resolvedAt;
        address resolvedBy;
    }

    // Recovery configuration
    struct RecoveryConfig {
        address treasury;        // Treasury address for recovered funds
        address systemContract;  // Main system contract (EducLearning)
        uint256 cooldownPeriod;  // Cooldown between recoveries
        uint256 approvalThreshold; // Required approvals for recoveries
    }

    // Multisig contract reference
    EducMultisig public multisig;
    
    // State variables
    RecoveryConfig public config;
    EmergencyLevel public currentEmergencyLevel;
    mapping(uint256 => EmergencyAction) public emergencyActions;
    uint256 public emergencyActionCount;
    mapping(address => mapping(address => uint256)) public lastRecoveryTimestamp;
    
    // Emergency approvals tracking
    mapping(uint256 => mapping(address => bool)) public emergencyApprovals;
    mapping(uint256 => uint256) public emergencyApprovalCount;

    // Constants
    uint256 public constant MAX_DESCRIPTION_LENGTH = 500;

    // Events
    event EmergencyDeclared(
        uint256 indexed actionId,
        EmergencyLevel level,
        address indexed triggeredBy,
        string reason,
        uint256 timestamp
    );

    event EmergencyResolved(
        uint256 indexed actionId,
        address indexed resolvedBy,
        uint256 timestamp
    );

    event EmergencyLevelChanged(
        EmergencyLevel oldLevel,
        EmergencyLevel newLevel,
        address changedBy,
        uint256 timestamp
    );

    event TokensRecovered(
        address indexed token,
        address indexed from,
        uint256 amount,
        address indexed to,
        address recoveredBy,
        uint256 timestamp
    );

    event RecoveryApproved(
        uint256 indexed actionId,
        address indexed approver,
        uint256 timestamp
    );

    event ConfigUpdated(
        address oldTreasury,
        address newTreasury,
        address oldSystemContract,
        address newSystemContract,
        uint256 oldCooldown,
        uint256 newCooldown,
        uint256 oldThreshold,
        uint256 newThreshold,
        uint256 timestamp
    );

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
        require(_admin != address(0), "EducEmergencyRecovery: Invalid admin address");
        require(_treasury != address(0), "EducEmergencyRecovery: Invalid treasury address");
        require(_systemContract != address(0), "EducEmergencyRecovery: Invalid system contract address");
        require(_multisig != address(0), "EducEmergencyRecovery: Invalid multisig address");

        // Grant admin role
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(EducRoles.ADMIN_ROLE, _admin);
        _grantRole(EducRoles.EMERGENCY_ROLE, _admin);
        
        // Set recovery config
        config = RecoveryConfig({
            treasury: _treasury,
            systemContract: _systemContract,
            cooldownPeriod: 7 days,
            approvalThreshold: 2
        });
        
        // Set multisig
        multisig = EducMultisig(_multisig);
        
        // No emergency by default
        currentEmergencyLevel = EmergencyLevel.None;
    }

    /**
     * @dev Declares an emergency situation
     * @param level Emergency level
     * @param reason Reason for emergency
     */
    function declareEmergency(
        EmergencyLevel level,
        string calldata reason
    ) 
        external
        nonReentrant
        onlyRole(EducRoles.EMERGENCY_ROLE)
    {
        require(level != EmergencyLevel.None && level != EmergencyLevel.Resolved, "EducEmergencyRecovery: Invalid emergency level");
        require(bytes(reason).length > 0 && bytes(reason).length <= MAX_DESCRIPTION_LENGTH, "EducEmergencyRecovery: Invalid reason length");
        
        EmergencyLevel oldLevel = currentEmergencyLevel;
        currentEmergencyLevel = level;

        uint256 actionId = ++emergencyActionCount;
        emergencyActions[actionId] = EmergencyAction({
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

        emit EmergencyDeclared(
            actionId,
            level,
            msg.sender,
            reason,
            block.timestamp
        );
        
        emit EmergencyLevelChanged(
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
        require(multisig.isSigner(msg.sender), "EducEmergencyRecovery: Not a multisig signer");
        require(actionId > 0 && actionId <= emergencyActionCount, "EducEmergencyRecovery: Invalid action ID");
        require(emergencyActions[actionId].isActive, "EducEmergencyRecovery: Action not active");
        require(!emergencyApprovals[actionId][msg.sender], "EducEmergencyRecovery: Already approved");
        
        emergencyApprovals[actionId][msg.sender] = true;
        emergencyApprovalCount[actionId]++;
        
        emit RecoveryApproved(
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
        require(actionId > 0 && actionId <= emergencyActionCount, "EducEmergencyRecovery: Invalid action ID");
        require(emergencyActions[actionId].isActive, "EducEmergencyRecovery: Action not active");
        require(emergencyApprovalCount[actionId] >= config.approvalThreshold, "EducEmergencyRecovery: Insufficient approvals");
        
        EmergencyAction storage action = emergencyActions[actionId];
        action.isActive = false;
        action.resolvedAt = block.timestamp;
        action.resolvedBy = msg.sender;
        
        EmergencyLevel oldLevel = currentEmergencyLevel;
        currentEmergencyLevel = EmergencyLevel.Resolved;
        
        emit EmergencyResolved(
            actionId,
            msg.sender,
            block.timestamp
        );
        
        emit EmergencyLevelChanged(
            oldLevel,
            EmergencyLevel.Resolved,
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
        require(token != address(0), "EducEmergencyRecovery: Invalid token address");
        require(from != address(0), "EducEmergencyRecovery: Invalid from address");
        require(amount > 0, "EducEmergencyRecovery: Amount must be positive");
        require(
            currentEmergencyLevel == EmergencyLevel.Level2 || 
            currentEmergencyLevel == EmergencyLevel.Level3,
            "EducEmergencyRecovery: Emergency level not high enough"
        );
        
        // Check cooldown period
        require(
            block.timestamp > lastRecoveryTimestamp[token][from] + config.cooldownPeriod,
            "EducEmergencyRecovery: Cooldown period not elapsed"
        );
        
        // Ensure we have an active emergency with enough approvals
        bool hasApprovedEmergency = false;
        for (uint256 i = 1; i <= emergencyActionCount; i++) {
            if (emergencyActions[i].isActive && emergencyApprovalCount[i] >= config.approvalThreshold) {
                hasApprovedEmergency = true;
                break;
            }
        }
        require(hasApprovedEmergency, "EducEmergencyRecovery: No approved emergency");

        // Record recovery timestamp
        lastRecoveryTimestamp[token][from] = block.timestamp;
        
        // Create low-level call to recover tokens
        // This approach works for contracts that don't have explicit recovery functions
        (bool success, bytes memory data) = from.call(
            abi.encodeWithSelector(
                IERC20(token).transfer.selector,
                config.treasury,
                amount
            )
        );
        
        if (!success) {
            // Try alternate approach if direct transfer fails
            bytes memory callData = abi.encodeWithSelector(
                bytes4(keccak256("executeEmergencyWithdrawal(address,uint256)")),
                token,
                amount
            );
            
            (success, data) = from.call(callData);
            
            require(success, "EducEmergencyRecovery: Recovery failed");
        }
        
        emit TokensRecovered(
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
        require(from != address(0), "EducEmergencyRecovery: Invalid from address");
        require(amount > 0, "EducEmergencyRecovery: Amount must be positive");
        require(
            currentEmergencyLevel == EmergencyLevel.Level3,
            "EducEmergencyRecovery: Emergency level not high enough"
        );
        
        // Check cooldown period
        address ETH_PSEUDO_ADDRESS = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
        require(
            block.timestamp > lastRecoveryTimestamp[ETH_PSEUDO_ADDRESS][from] + config.cooldownPeriod,
            "EducEmergencyRecovery: Cooldown period not elapsed"
        );
        
        // Ensure we have an active emergency with enough approvals
        bool hasApprovedEmergency = false;
        for (uint256 i = 1; i <= emergencyActionCount; i++) {
            if (emergencyActions[i].isActive && emergencyApprovalCount[i] >= config.approvalThreshold) {
                hasApprovedEmergency = true;
                break;
            }
        }
        require(hasApprovedEmergency, "EducEmergencyRecovery: No approved emergency");

        // Record recovery timestamp
        lastRecoveryTimestamp[ETH_PSEUDO_ADDRESS][from] = block.timestamp;
        
        // Try to recover ETH
        bytes memory callData = abi.encodeWithSelector(
            bytes4(keccak256("executeEmergencyETHWithdrawal(uint256)")),
            amount
        );
        
        (bool success, ) = from.call(callData);
        require(success, "EducEmergencyRecovery: ETH recovery failed");
        
        emit TokensRecovered(
            ETH_PSEUDO_ADDRESS,
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
        require(_treasury != address(0), "EducEmergencyRecovery: Invalid treasury address");
        require(_systemContract != address(0), "EducEmergencyRecovery: Invalid system contract address");
        require(_cooldownPeriod > 0, "EducEmergencyRecovery: Invalid cooldown period");
        require(_approvalThreshold > 0, "EducEmergencyRecovery: Invalid approval threshold");
        
        address oldTreasury = config.treasury;
        address oldSystemContract = config.systemContract;
        uint256 oldCooldown = config.cooldownPeriod;
        uint256 oldThreshold = config.approvalThreshold;
        
        config.treasury = _treasury;
        config.systemContract = _systemContract;
        config.cooldownPeriod = _cooldownPeriod;
        config.approvalThreshold = _approvalThreshold;
        
        emit ConfigUpdated(
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
    function setEmergencyLevel(EmergencyLevel newLevel) 
        external
        onlyRole(EducRoles.EMERGENCY_ROLE)
    {
        require(
            uint8(newLevel) <= uint8(currentEmergencyLevel), 
            "EducEmergencyRecovery: Cannot escalate emergency level"
        );
        
        EmergencyLevel oldLevel = currentEmergencyLevel;
        currentEmergencyLevel = newLevel;
        
        emit EmergencyLevelChanged(
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
        EmergencyLevel level,
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
    
    EmergencyAction storage action = emergencyActions[actionId];
    
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
}