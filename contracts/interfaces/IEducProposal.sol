// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../governance/proposal/types/ProposalTypes.sol";

interface IEducProposal {
    function createProposal(
        ProposalTypes.ProposalCreationParams calldata params
    ) external returns (uint256);

    function approveProposal(
        ProposalTypes.ProposalVoteParams calldata params
    ) external;

    function rejectProposal(
        ProposalTypes.ProposalVoteParams calldata params
    ) external;

    function checkProposalStatus(
        ProposalTypes.ProposalDetailsParams calldata params
    ) external returns (ProposalTypes.ProposalStatus);

    function getProposalDetails(
        ProposalTypes.ProposalDetailsParams calldata params
    ) external view returns (
        address proposer,
        ProposalTypes.InstructionType instructionType,
        ProposalTypes.ProposalStatus status,
        uint256 createdAt,
        uint256 expiresAt,
        string memory description,
        uint256 approverCount,
        uint256 rejectorCount,
        uint256 requiredApprovals
    );
}