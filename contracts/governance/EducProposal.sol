// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../access/EducRoles.sol";
import "./EducMultisig.sol";

/**
 * @title EducProposal
 * @dev Advanced governance proposal management system
 */
contract EducProposal is AccessControl, ReentrancyGuard {
    // Proposal lifecycle constants
    uint256 public constant MAX_DESCRIPTION_LENGTH = 500;
    uint256 public constant PROPOSAL_EXPIRATION_TIME = 7 days;

    // Proposal status enum
    enum ProposalStatus {
        Pending,
        Active,
        Executed,
        Rejected,
        Expired
    }

    // Proposal instruction types
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

    // Proposal structure with comprehensive tracking
    struct Proposal {
        uint256 id;
        address proposer;
        InstructionType instructionType;
        bytes data;
        address[] approvers;
        address[] rejectors;
        ProposalStatus status;
        uint256 createdAt;
        uint256 expiresAt;
        string description;
        uint256 requiredApprovals;
    }

    // Storage mappings
    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCount;

    // Multisig reference
    EducMultisig public multisig;

    // Events with comprehensive logging
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        InstructionType instructionType,
        uint256 timestamp
    );

    event ProposalApproved(
        uint256 indexed proposalId,
        address indexed approver,
        uint256 approvalCount,
        uint256 timestamp
    );

    event ProposalRejected(
        uint256 indexed proposalId,
        address indexed rejector,
        uint256 rejectionCount,
        uint256 timestamp
    );

    event ProposalExecuted(
        uint256 indexed proposalId,
        address indexed executor,
        uint256 timestamp
    );

    event ProposalExpired(
        uint256 indexed proposalId,
        uint256 timestamp
    );

    /**
     * @dev Constructor sets up admin roles and multisig reference
     * @param _multisig Multisig contract address
     * @param admin Administrator address
     */
    constructor(address _multisig, address admin) {
        require(_multisig != address(0), "EducProposal: Invalid multisig");
        require(admin != address(0), "EducProposal: Invalid admin");

        multisig = EducMultisig(_multisig);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(EducRoles.ADMIN_ROLE, admin);
    }

    /**
     * @dev Creates a new proposal
     * @param instructionType Type of proposal instruction
     * @param data Encoded proposal data
     * @param description Proposal description
     * @param requiredApprovals Number of approvals needed
     */
    function createProposal(
        InstructionType instructionType,
        bytes calldata data,
        string calldata description,
        uint256 requiredApprovals
    ) 
        external 
        nonReentrant 
        returns (uint256) 
    {
        require(
            multisig.isSigner(msg.sender), 
            "EducProposal: Caller not a signer"
        );
        require(
            bytes(description).length <= MAX_DESCRIPTION_LENGTH,
            "EducProposal: Description too long"
        );
        require(
            requiredApprovals > 0 && 
            requiredApprovals <= multisig.threshold(),
            "EducProposal: Invalid approval requirement"
        );

        proposalCount++;

        proposals[proposalCount] = Proposal({
            id: proposalCount,
            proposer: msg.sender,
            instructionType: instructionType,
            data: data,
            approvers: new address[](0),
            rejectors: new address[](0),
            status: ProposalStatus.Pending,
            createdAt: block.timestamp,
            expiresAt: block.timestamp + PROPOSAL_EXPIRATION_TIME,
            description: description,
            requiredApprovals: requiredApprovals
        });

        emit ProposalCreated(
            proposalCount, 
            msg.sender, 
            instructionType, 
            block.timestamp
        );

        return proposalCount;
    }

    /**
     * @dev Approves a proposal
     * @param proposalId Proposal identifier
     */
    function approveProposal(uint256 proposalId) 
        external 
        nonReentrant 
    {
        Proposal storage proposal = proposals[proposalId];
        
        require(
            multisig.isSigner(msg.sender), 
            "EducProposal: Caller not a signer"
        );
        require(
            proposal.status == ProposalStatus.Pending, 
            "EducProposal: Invalid proposal status"
        );
        require(
            block.timestamp < proposal.expiresAt, 
            "EducProposal: Proposal expired"
        );

        // Prevent duplicate approvals and rejections
        for (uint256 i = 0; i < proposal.approvers.length; i++) {
            require(
                proposal.approvers[i] != msg.sender, 
                "EducProposal: Already approved"
            );
        }

        for (uint256 i = 0; i < proposal.rejectors.length; i++) {
            require(
                proposal.rejectors[i] != msg.sender, 
                "EducProposal: Cannot approve after rejection"
            );
        }

        proposal.approvers.push(msg.sender);

        emit ProposalApproved(
            proposalId, 
            msg.sender, 
            proposal.approvers.length,
            block.timestamp
        );

        // Check if proposal meets approval threshold
        if (proposal.approvers.length >= proposal.requiredApprovals) {
            _executeProposal(proposalId);
        }
    }

    /**
     * @dev Rejects a proposal
     * @param proposalId Proposal identifier
     */
    function rejectProposal(uint256 proposalId) 
        external 
        nonReentrant 
    {
        Proposal storage proposal = proposals[proposalId];
        
        require(
            multisig.isSigner(msg.sender), 
            "EducProposal: Caller not a signer"
        );
        require(
            proposal.status == ProposalStatus.Pending, 
            "EducProposal: Invalid proposal status"
        );

        // Prevent duplicate rejections and approvals
        for (uint256 i = 0; i < proposal.rejectors.length; i++) {
            require(
                proposal.rejectors[i] != msg.sender, 
                "EducProposal: Already rejected"
            );
        }

        for (uint256 i = 0; i < proposal.approvers.length; i++) {
            require(
                proposal.approvers[i] != msg.sender, 
                "EducProposal: Cannot reject after approval"
            );
        }

        proposal.rejectors.push(msg.sender);

        emit ProposalRejected(
            proposalId, 
            msg.sender, 
            proposal.rejectors.length,
            block.timestamp
        );

        // Optional: Auto-reject if majority rejects
        if (proposal.rejectors.length > multisig.threshold() / 2) {
            proposal.status = ProposalStatus.Rejected;
        }
    }

    /**
     * @dev Internal proposal execution logic
     * @param proposalId Proposal identifier
     */
    function _executeProposal(uint256 proposalId) internal {
        Proposal storage proposal = proposals[proposalId];
        
        proposal.status = ProposalStatus.Executed;

        // Execute based on instruction type
        if (proposal.instructionType == InstructionType.AddSigner) {
            address signerToAdd = abi.decode(proposal.data, (address));
            multisig.addSigner(signerToAdd);
        } else if (proposal.instructionType == InstructionType.RemoveSigner) {
            address signerToRemove = abi.decode(proposal.data, (address));
            multisig.removeSigner(signerToRemove);
        } else if (proposal.instructionType == InstructionType.ChangeThreshold) {
            uint8 newThreshold = abi.decode(proposal.data, (uint8));
            multisig.changeThreshold(newThreshold);
        }
        // Additional instruction types can be added here

        emit ProposalExecuted(
            proposalId, 
            msg.sender, 
            block.timestamp
        );
    }

    /**
     * @dev Checks and updates proposal status if expired
     * @param proposalId Proposal identifier
     * @return Current proposal status
     */
    function checkProposalStatus(uint256 proposalId) 
        external 
        returns (ProposalStatus) 
    {
        Proposal storage proposal = proposals[proposalId];
        
        if (block.timestamp >= proposal.expiresAt && 
            proposal.status == ProposalStatus.Pending) {
            proposal.status = ProposalStatus.Expired;
            
            emit ProposalExpired(proposalId, block.timestamp);
            return ProposalStatus.Expired;
        }
        
        return proposal.status;
    }

    /**
     * @dev Retrieves proposal details
     * @param proposalId Proposal identifier
     * @return proposer Address of proposal creator
     * @return instructionType Type of proposal instruction
     * @return status Current proposal status
     * @return createdAt Timestamp of proposal creation
     * @return expiresAt Timestamp when proposal expires
     * @return description Proposal description
     * @return approverCount Number of approvers
     * @return rejectorCount Number of rejectors
     * @return requiredApprovals Minimum approvals needed
     */
    function getProposalDetails(uint256 proposalId) 
        external 
        view 
        returns (
            address proposer,
            InstructionType instructionType,
            ProposalStatus status,
            uint256 createdAt,
            uint256 expiresAt,
            string memory description,
            uint256 approverCount,
            uint256 rejectorCount,
            uint256 requiredApprovals
        ) 
    {
        Proposal storage proposal = proposals[proposalId];
        
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
}