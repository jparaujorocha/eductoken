// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;


import "./types/EmergencyTypes.sol";

/**
 * @title EmergencyEvents
 * @dev Defines events for the Emergency module
 */
library EmergencyEvents {
    /**
     * @dev Emitted when an emergency is declared
     * @param actionId ID of the emergency action
     * @param level Severity level of the emergency
     * @param triggeredBy Address that declared the emergency
     * @param reason Reason for the emergency
     * @param timestamp When the emergency was declared
     */
    event EmergencyDeclared(
        uint256 indexed actionId,
        EmergencyTypes.EmergencyLevel level,
        address indexed triggeredBy,
        string reason,
        uint256 timestamp
    );

    /**
     * @dev Emitted when an emergency is resolved
     * @param actionId ID of the emergency action
     * @param resolvedBy Address that resolved the emergency
     * @param timestamp When the emergency was resolved
     */
    event EmergencyResolved(
        uint256 indexed actionId,
        address indexed resolvedBy,
        uint256 timestamp
    );

    /**
     * @dev Emitted when the emergency level changes
     * @param oldLevel Previous emergency level
     * @param newLevel New emergency level
     * @param changedBy Address that changed the level
     * @param timestamp When the level was changed
     */
    event EmergencyLevelChanged(
        EmergencyTypes.EmergencyLevel oldLevel,
        EmergencyTypes.EmergencyLevel newLevel,
        address changedBy,
        uint256 timestamp
    );

    /**
     * @dev Emitted when tokens are recovered in an emergency
     * @param token Address of the token (ETH_PSEUDO_ADDRESS for ETH)
     * @param from Contract address tokens were recovered from
     * @param amount Amount of tokens recovered
     * @param to Address that received the recovered tokens
     * @param recoveredBy Address that performed the recovery
     * @param timestamp When the recovery occurred
     */
    event TokensRecovered(
        address indexed token,
        address indexed from,
        uint256 amount,
        address indexed to,
        address recoveredBy,
        uint256 timestamp
    );

    /**
     * @dev Emitted when an emergency action is approved
     * @param actionId ID of the emergency action
     * @param approver Address that approved the action
     * @param timestamp When the approval occurred
     */
    event RecoveryApproved(
        uint256 indexed actionId,
        address indexed approver,
        uint256 timestamp
    );

    /**
     * @dev Emitted when recovery configuration is updated
     * @param oldTreasury Previous treasury address
     * @param newTreasury New treasury address
     * @param oldSystemContract Previous system contract address
     * @param newSystemContract New system contract address
     * @param oldCooldown Previous cooldown period
     * @param newCooldown New cooldown period
     * @param oldThreshold Previous approval threshold
     * @param newThreshold New approval threshold
     * @param timestamp When the configuration was updated
     */
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
     * @dev Emitted when an emergency withdrawal is executed
     * @param token Token address
     * @param amount Amount withdrawn
     * @param destination Destination address
     * @param timestamp When the withdrawal occurred
     */
    event EmergencyWithdrawal(
        address indexed token,
        uint256 amount,
        address indexed destination,
        uint256 timestamp
    );

    /**
     * @dev Emitted when an emergency ETH withdrawal is executed
     * @param amount Amount of ETH withdrawn
     * @param destination Destination address
     * @param timestamp When the withdrawal occurred
     */
    event EmergencyETHWithdrawal(
        uint256 amount,
        address indexed destination,
        uint256 timestamp
    );

    /**
     * @dev Emitted when the recovery destination is updated
     * @param previousDestination Previous recovery destination
     * @param newDestination New recovery destination
     * @param timestamp When the destination was updated
     */
    event RecoveryDestinationUpdated(
        address previousDestination,
        address newDestination,
        uint256 timestamp
    );
    
    /**
     * @dev Emitted when the emergency recovery contract is updated
     * @param previousContract Previous emergency recovery contract
     * @param newContract New emergency recovery contract
     * @param timestamp When the contract was updated
     */
    event EmergencyRecoveryContractUpdated(
        address previousContract,
        address newContract,
        uint256 timestamp
    );
}