// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./types/ProposalTypes.sol";

/**
 * @title ProposalEvents
 * @dev Defines events for the Proposal module
 */
library ProposalEvents {
    /**
     * @dev Emitted when a proposal is created
     * @param proposalId ID of the created proposal
     * @param proposer Address that created the proposal
     * @param instructionType Type of instruction for the proposal
     * @param timestamp When the proposal was created
     */
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        ProposalTypes.InstructionType instructionType,
        uint256 timestamp
    );

    /**
     * @dev Emitted when a proposal is approved by a signer
     * @param proposalId ID of the proposal
     * @param approver Address that approved the proposal
     * @param approvalCount Current number of approvals for the proposal
     * @param timestamp When the approval occurred
     */
    event ProposalApproved(
        uint256 indexed proposalId,
        address indexed approver,
        uint256 approvalCount,
        uint256 timestamp
    );

    /**
     * @dev Emitted when a proposal is rejected by a signer
     * @param proposalId ID of the proposal
     * @param rejector Address that rejected the proposal
     * @param rejectionCount Current number of rejections for the proposal
     * @param timestamp When the rejection occurred
     */
    event ProposalRejected(
        uint256 indexed proposalId,
        address indexed rejector,
        uint256 rejectionCount,
        uint256 timestamp
    );

    /**
     * @dev Emitted when a proposal is executed
     * @param proposalId ID of the proposal
     * @param executor Address that executed the proposal
     * @param timestamp When the execution occurred
     */
    event ProposalExecuted(
        uint256 indexed proposalId,
        address indexed executor,
        uint256 timestamp
    );

    /**
     * @dev Emitted when a proposal expires
     * @param proposalId ID of the proposal
     * @param timestamp When the expiration was recorded
     */
    event ProposalExpired(
        uint256 indexed proposalId,
        uint256 timestamp
    );
    
    /**
     * @dev Emitted when a proposal is cancelled
     * @param proposalId ID of the proposal
     * @param canceler Address that cancelled the proposal
     * @param timestamp When the cancellation occurred
     */
    event ProposalCancelled(
        uint256 indexed proposalId,
        address indexed canceler,
        uint256 timestamp
    );
}