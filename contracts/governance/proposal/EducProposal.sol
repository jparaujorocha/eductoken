// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../../access/roles/EducRoles.sol";
import "../../config/constants/SystemConstants.sol";
import "../../interfaces/IEducProposal.sol";
import "../../interfaces/IEducMultisig.sol";
import "./ProposalEvents.sol";
import "./types/ProposalTypes.sol";
import "../../governance/multisig/EducMultisig.sol";

/**
 * @title EducProposal
 * @dev Advanced governance proposal management system
 */
contract EducProposal is AccessControl, ReentrancyGuard, IEducProposal {
    // Constants
    uint256 public constant MAX_DESCRIPTION_LENGTH = 500;
    uint256 public constant PROPOSAL_EXPIRATION_TIME = 7 days;

    // Storage mappings
    mapping(uint256 => ProposalTypes.Proposal) public proposals;
    uint256 public proposalCount;

    // Multisig reference
    EducMultisig public multisig;

    /**
     * @dev Constructor sets up admin roles and multisig reference
     * @param _multisig Multisig contract address
     * @param admin Administrator address
     */
    constructor(address _multisig, address admin) {
        _validateConstructorParams(_multisig, admin);
        multisig = EducMultisig(_multisig);
        _setupRoles(admin);
    }

    function _validateConstructorParams(address _multisig, address admin) private pure {
        require(_multisig != address(0), "EducProposal: Invalid multisig");
        require(admin != address(0), "EducProposal: Invalid admin");
    }

    function _setupRoles(address admin) private {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(EducRoles.ADMIN_ROLE, admin);
    }

    function createProposal(ProposalTypes.ProposalCreationParams calldata params) 
        external 
        nonReentrant 
        returns (uint256) 
    {
        _validateProposalCreation(params);
        proposalCount++;
        _initializeProposal(params);
        _emitProposalCreatedEvent(proposalCount, params.instructionType);
        return proposalCount;
    }

    function _validateProposalCreation(ProposalTypes.ProposalCreationParams calldata params) private view {
        require(multisig.isSigner(msg.sender), "EducProposal: Caller not a signer");
        require(bytes(params.description).length <= MAX_DESCRIPTION_LENGTH, "EducProposal: Description too long");
        require(params.requiredApprovals > 0 && params.requiredApprovals <= multisig.threshold(), "EducProposal: Invalid approval requirement");
    }

    function _initializeProposal(ProposalTypes.ProposalCreationParams calldata params) private {
        ProposalTypes.Proposal storage newProposal = proposals[proposalCount];
        newProposal.id = proposalCount;
        newProposal.proposer = msg.sender;
        newProposal.instructionType = params.instructionType;
        newProposal.data = params.data;
        newProposal.approvers = new address[](0);
        newProposal.rejectors = new address[](0);
        newProposal.status = ProposalTypes.ProposalStatus.Pending;
        newProposal.createdAt = block.timestamp;
        newProposal.expiresAt = block.timestamp + PROPOSAL_EXPIRATION_TIME;
        newProposal.description = params.description;
        newProposal.requiredApprovals = params.requiredApprovals;
    }

    function _emitProposalCreatedEvent(uint256 proposalId, ProposalTypes.InstructionType instructionType) private {
        emit ProposalEvents.ProposalCreated(proposalId, msg.sender, instructionType, block.timestamp);
    }

    function approveProposal(ProposalTypes.ProposalVoteParams calldata params) 
        external 
        nonReentrant 
    {
        ProposalTypes.Proposal storage proposal = proposals[params.proposalId];
        _validateProposalApproval(proposal);
        proposal.approvers.push(msg.sender);
        _emitProposalApprovedEvent(params.proposalId, proposal.approvers.length);
        if (proposal.approvers.length >= proposal.requiredApprovals) {
            _executeProposal(params.proposalId);
        }
    }

    function _validateProposalApproval(ProposalTypes.Proposal storage proposal) private view {
        require(multisig.isSigner(msg.sender), "EducProposal: Caller not a signer");
        require(proposal.status == ProposalTypes.ProposalStatus.Pending, "EducProposal: Invalid proposal status");
        require(block.timestamp < proposal.expiresAt, "EducProposal: Proposal expired");
        _checkDuplicateVotes(proposal, msg.sender, true);
    }

    function rejectProposal(ProposalTypes.ProposalVoteParams calldata params) 
        external 
        nonReentrant 
    {
        ProposalTypes.Proposal storage proposal = proposals[params.proposalId];
        _validateProposalRejection(proposal);
        proposal.rejectors.push(msg.sender);
        _emitProposalRejectedEvent(params.proposalId, proposal.rejectors.length);
        if (proposal.rejectors.length > multisig.threshold() / 2) {
            proposal.status = ProposalTypes.ProposalStatus.Rejected;
        }
    }

    function _validateProposalRejection(ProposalTypes.Proposal storage proposal) private view {
        require(multisig.isSigner(msg.sender), "EducProposal: Caller not a signer");
        require(proposal.status == ProposalTypes.ProposalStatus.Pending, "EducProposal: Invalid proposal status");
        _checkDuplicateVotes(proposal, msg.sender, false);
    }

    function _checkDuplicateVotes(ProposalTypes.Proposal storage proposal, address voter, bool isApproval) private view {
        if (isApproval) {
            _checkDuplicateApprovals(proposal, voter);
        } else {
            _checkDuplicateRejections(proposal, voter);
        }
    }

    function _checkDuplicateApprovals(ProposalTypes.Proposal storage proposal, address voter) private view {
        for (uint256 i = 0; i < proposal.approvers.length; i++) {
            require(proposal.approvers[i] != voter, "EducProposal: Already approved");
        }
        for (uint256 i = 0; i < proposal.rejectors.length; i++) {
            require(proposal.rejectors[i] != voter, "EducProposal: Cannot approve after rejection");
        }
    }

    function _checkDuplicateRejections(ProposalTypes.Proposal storage proposal, address voter) private view {
        for (uint256 i = 0; i < proposal.rejectors.length; i++) {
            require(proposal.rejectors[i] != voter, "EducProposal: Already rejected");
        }
        for (uint256 i = 0; i < proposal.approvers.length; i++) {
            require(proposal.approvers[i] != voter, "EducProposal: Cannot reject after approval");
        }
    }

    function _executeProposal(uint256 proposalId) internal {
        ProposalTypes.Proposal storage proposal = proposals[proposalId];
        proposal.status = ProposalTypes.ProposalStatus.Executed;
        _executeProposalByType(proposal);
        _emitProposalExecutedEvent(proposalId);
    }

    function _executeProposalByType(ProposalTypes.Proposal storage proposal) private {
        if (proposal.instructionType == ProposalTypes.InstructionType.AddSigner) {
            address signerToAdd = abi.decode(proposal.data, (address));
            multisig.addSigner(signerToAdd);
        } else if (proposal.instructionType == ProposalTypes.InstructionType.RemoveSigner) {
            address signerToRemove = abi.decode(proposal.data, (address));
            multisig.removeSigner(signerToRemove);
        } else if (proposal.instructionType == ProposalTypes.InstructionType.ChangeThreshold) {
            uint8 newThreshold = uint8(uint256(abi.decode(proposal.data, (uint256))));
            multisig.changeThreshold(newThreshold);
        }
    }

    function checkProposalStatus(ProposalTypes.ProposalDetailsParams calldata params) 
        external 
        returns (ProposalTypes.ProposalStatus) 
    {
        ProposalTypes.Proposal storage proposal = proposals[params.proposalId];
        if (block.timestamp >= proposal.expiresAt && proposal.status == ProposalTypes.ProposalStatus.Pending) {
            proposal.status = ProposalTypes.ProposalStatus.Expired;
            _emitProposalExpiredEvent(params.proposalId);
            return ProposalTypes.ProposalStatus.Expired;
        }
        return proposal.status;
    }

    function getProposalDetails(ProposalTypes.ProposalDetailsParams calldata params) 
        external 
        view 
        returns (
            address proposer,
            ProposalTypes.InstructionType instructionType,
            ProposalTypes.ProposalStatus status,
            uint256 createdAt,
            uint256 expiresAt,
            string memory description,
            uint256 approverCount,
            uint256 rejectorCount,
            uint256 requiredApprovals
        ) 
    {
        ProposalTypes.Proposal storage proposal = proposals[params.proposalId];
        return (
            proposal.proposer,
            proposal.instructionType,
            proposal.status,
            proposal.createdAt,
            proposal.expiresAt,
            proposal.description,
            proposal.approvers.length,
            proposal.rejectors.length,
            proposal.requiredApprovals
        );
    }

    function _emitProposalApprovedEvent(uint256 proposalId, uint256 approverCount) private {
        emit ProposalEvents.ProposalApproved(proposalId, msg.sender, approverCount, block.timestamp);
    }

    function _emitProposalRejectedEvent(uint256 proposalId, uint256 rejectorCount) private {
        emit ProposalEvents.ProposalRejected(proposalId, msg.sender, rejectorCount, block.timestamp);
    }

    function _emitProposalExecutedEvent(uint256 proposalId) private {
        emit ProposalEvents.ProposalExecuted(proposalId, msg.sender, block.timestamp);
    }

    function _emitProposalExpiredEvent(uint256 proposalId) private {
        emit ProposalEvents.ProposalExpired(proposalId, block.timestamp);
    }
}