// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ProposalTypes
 * @dev Defines type structures for the Governance Proposal module
 */
library ProposalTypes {
    /**
     * @dev Represents proposal status in the system
     */
    enum ProposalStatus {
        Pending,    // Proposal is created but not yet decided
        Active,     // Proposal is actively being voted on
        Executed,   // Proposal has been successfully executed
        Rejected,   // Proposal has been rejected
        Expired     // Proposal has passed its voting deadline
    }
    
    /**
     * @dev Represents different types of proposal instructions
     */
    enum InstructionType {
        UpdateConfig,
        RegisterEducator,
        UpdateEducatorStatus,
        CreateCourse,
        UpdateCourse,
        AddSigner,
        RemoveSigner,
        ChangeThreshold,
        TransferFunds,
        EmergencyPause
    }
    
    /**
     * @dev Tracks a governance proposal
     */
    struct Proposal {
        uint256 id;                  // Unique identifier for the proposal
        address proposer;            // Address that created the proposal
        InstructionType instructionType; // Type of proposal instruction
        bytes data;                  // Encoded proposal data
        address[] approvers;         // Addresses that have approved the proposal
        address[] rejectors;         // Addresses that have rejected the proposal
        ProposalStatus status;       // Current status of the proposal
        uint256 createdAt;           // Timestamp when proposal was created
        uint256 expiresAt;           // Timestamp when proposal expires
        string description;          // Description of the proposal
        uint256 requiredApprovals;   // Number of approvals needed to execute
    }
    
    /**
     * @dev Parameters for creating a new proposal
     */
    struct ProposalCreationParams {
        InstructionType instructionType; // Type of proposal instruction
        bytes data;                  // Encoded proposal data
        string description;          // Description of the proposal
        uint256 requiredApprovals;   // Number of approvals needed to execute
    }
    
    /**
     * @dev Parameters for approving or rejecting a proposal
     */
    struct ProposalVoteParams {
        uint256 proposalId;          // ID of the proposal to vote on
    }
    
    /**
     * @dev Details for retrieving proposal information
     */
    struct ProposalDetailsParams {
        uint256 proposalId;          // ID of the proposal to retrieve
    }
}