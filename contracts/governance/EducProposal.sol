// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../access/EducRoles.sol";
import "./EducMultisig.sol";

/**
 * @title EducProposal
 * @dev Manages governance proposals in the EducLearning system
 */
contract EducProposal is AccessControl, ReentrancyGuard {
    // Constants
    uint256 public constant MAX_DESCRIPTION_LENGTH = 200;
    uint256 public constant PROPOSAL_EXPIRATION_TIME = 7 days;
    
    // Enum for proposal status
    enum ProposalStatus {
        Active,
        Executed,
        Cancelled,
        Expired
    }
    
    // Enum for proposal instruction types
    enum InstructionType {
        ChangeAuthority,
        TogglePause,
        RegisterEducator,
        UpdateEducatorStatus,
        AddSigner,
        RemoveSigner,
        ChangeThreshold
    }
    
    // Structure for proposal instructions
    struct ProposalInstruction {
        InstructionType instructionType;
        bytes data;
    }
    
    // Structure for proposals
    struct Proposal {
        uint256 index;
        address multisig;
        ProposalInstruction instruction;
        mapping(address => bool) approvals;
        ProposalStatus status;
        uint256 createdAt;
        uint256 closedAt;
        string description;
        address proposer;
        uint8 approvalCount;
    }
    
    // Storage
    mapping(uint256 => Proposal) public proposals;
    EducMultisig public multisig;
    
    // Events
    event ProposalCreated(
        uint256 indexed proposalId,
        address multisig,
        address indexed proposer,
        uint256 timestamp,
        string description
    );
    
    event ProposalApproved(
        uint256 indexed proposalId,
        address indexed signer,
        uint256 timestamp
    );
    
    event ProposalExecuted(
        uint256 indexed proposalId,
        address indexed executor,
        uint256 timestamp
    );
    
    event ProposalCancelled(
        uint256 indexed proposalId,
        address indexed canceller,
        uint256 timestamp
    );
    
    /**
     * @dev Constructor to initialize the proposal contract
     * @param multisigAddress Address of the multisig contract
     * @param admin Admin address
     */
    constructor(address multisigAddress, address admin) {
        require(multisigAddress != address(0), "EducProposal: multisig cannot be zero address");
        require(admin != address(0), "EducProposal: admin cannot be zero address");
        
        multisig = EducMultisig(multisigAddress);
        
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole(EducRoles.ADMIN_ROLE, admin);
    }
    
    /**
     * @dev Creates a new proposal
     * @param instruction Proposal instruction
     * @param description Description of the proposal
     * @return uint256 ID of the created proposal
     */
    function createProposal(
        ProposalInstruction memory instruction,
        string calldata description
    ) 
        external 
        nonReentrant 
        returns (uint256) 
    {
        require(bytes(description).length <= MAX_DESCRIPTION_LENGTH, "EducProposal: description too long");
        require(multisig.isSigner(msg.sender), "EducProposal: caller is not a signer");
        
        uint256 proposalId = multisig.proposalCount();
        uint256 currentTime = block.timestamp;
        
        Proposal storage proposal = proposals[proposalId];
        proposal.index = proposalId;
        proposal.multisig = address(multisig);
        proposal.instruction = instruction;
        proposal.status = ProposalStatus.Active;
        proposal.createdAt = currentTime;
        proposal.closedAt = 0;
        proposal.description = description;
        proposal.proposer = msg.sender;
        proposal.approvalCount = 1;
        
        // Auto-approve by the proposer
        proposal.approvals[msg.sender] = true;
        
        // Increment multisig proposal count
        multisig.incrementProposalCount();
        
        emit ProposalCreated(
            proposalId,
            address(multisig),
            msg.sender,
            currentTime,
            description
        );
        
        return proposalId;
    }
    
    /**
     * @dev Approves a proposal
     * @param proposalId ID of the proposal to approve
     */
    function approveProposal(uint256 proposalId) external nonReentrant {
        require(multisig.isSigner(msg.sender), "EducProposal: caller is not a signer");
        
        Proposal storage proposal = proposals[proposalId];
        require(proposal.createdAt > 0, "EducProposal: proposal does not exist");
        require(proposal.status == ProposalStatus.Active, "EducProposal: proposal is not active");
        require(!proposal.approvals[msg.sender], "EducProposal: already approved");
        
        // Check for expiration
        if (block.timestamp > proposal.createdAt + PROPOSAL_EXPIRATION_TIME) {
            proposal.status = ProposalStatus.Expired;
            proposal.closedAt = block.timestamp;
            emit ProposalCancelled(proposalId, msg.sender, block.timestamp);
            revert("EducProposal: proposal expired");
        }
        
        proposal.approvals[msg.sender] = true;
        proposal.approvalCount++;
        
        emit ProposalApproved(
            proposalId,
            msg.sender,
            block.timestamp
        );
    }
    
    /**
     * @dev Executes a proposal
     * @param proposalId ID of the proposal to execute
     */
    function executeProposal(uint256 proposalId) external nonReentrant {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.createdAt > 0, "EducProposal: proposal does not exist");
        require(proposal.status == ProposalStatus.Active, "EducProposal: proposal is not active");
        
        // Check for expiration
        if (block.timestamp > proposal.createdAt + PROPOSAL_EXPIRATION_TIME) {
            proposal.status = ProposalStatus.Expired;
            proposal.closedAt = block.timestamp;
            emit ProposalCancelled(proposalId, msg.sender, block.timestamp);
            revert("EducProposal: proposal expired");
        }
        
        // Check for sufficient approvals
        require(proposal.approvalCount >= multisig.threshold(), "EducProposal: not enough approvals");
        
        // Execute the instruction based on its type
        executeInstruction(proposal.instruction);
        
        // Update proposal status
        proposal.status = ProposalStatus.Executed;
        proposal.closedAt = block.timestamp;
        
        emit ProposalExecuted(
            proposalId,
            msg.sender,
            block.timestamp
        );
    }
    
    /**
     * @dev Cancels a proposal
     * @param proposalId ID of the proposal to cancel
     */
    function cancelProposal(uint256 proposalId) external nonReentrant {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.createdAt > 0, "EducProposal: proposal does not exist");
        require(proposal.status == ProposalStatus.Active, "EducProposal: proposal is not active");
        
        // Only the proposer or an admin can cancel
        require(
            proposal.proposer == msg.sender || hasRole(EducRoles.ADMIN_ROLE, msg.sender),
            "EducProposal: not authorized to cancel"
        );
        
        proposal.status = ProposalStatus.Cancelled;
        proposal.closedAt = block.timestamp;
        
        emit ProposalCancelled(
            proposalId,
            msg.sender,
            block.timestamp
        );
    }
    
    /**
     * @dev Gets the details of a proposal
     * @param proposalId ID of the proposal
     * @return instruction, status, createdAt, closedAt, description, proposer, approvalCount
     */
    function getProposal(uint256 proposalId) 
        external 
        view 
        returns (
            ProposalInstruction memory,
            ProposalStatus,
            uint256,
            uint256,
            string memory,
            address,
            uint8
        ) 
    {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.createdAt > 0, "EducProposal: proposal does not exist");
        
        return (
            proposal.instruction,
            proposal.status,
            proposal.createdAt,
            proposal.closedAt,
            proposal.description,
            proposal.proposer,
            proposal.approvalCount
        );
    }
    
    /**
     * @dev Checks if a proposal has been approved by a specific signer
     * @param proposalId ID of the proposal
     * @param signer Address of the signer to check
     * @return bool True if the signer has approved the proposal
     */
    function hasApproved(uint256 proposalId, address signer) 
        external 
        view 
        returns (bool) 
    {
        return proposals[proposalId].approvals[signer];
    }
    
    /**
     * @dev Execute a proposal instruction
     * @param instruction The instruction to execute
     */
    function executeInstruction(ProposalInstruction memory instruction) private {
        if (instruction.instructionType == InstructionType.ChangeAuthority) {
            address newAuthority = abi.decode(instruction.data, (address));
            // Implementation depends on the target contracts
        } else if (instruction.instructionType == InstructionType.TogglePause) {
            bool pauseState = abi.decode(instruction.data, (bool));
            // Implementation depends on the target contracts
        } else if (instruction.instructionType == InstructionType.RegisterEducator) {
            (address educator, uint256 mintLimit) = abi.decode(instruction.data, (address, uint256));
            // Implementation depends on the target contracts
        } else if (instruction.instructionType == InstructionType.UpdateEducatorStatus) {
            (address educator, bool isActive, uint256 mintLimit) = abi.decode(instruction.data, (address, bool, uint256));
            // Implementation depends on the target contracts
        } else if (instruction.instructionType == InstructionType.AddSigner) {
            address newSigner = abi.decode(instruction.data, (address));
            multisig.addSigner(newSigner);
        } else if (instruction.instructionType == InstructionType.RemoveSigner) {
            address signerToRemove = abi.decode(instruction.data, (address));
            multisig.removeSigner(signerToRemove);
        } else if (instruction.instructionType == InstructionType.ChangeThreshold) {
            uint8 newThreshold = abi.decode(instruction.data, (uint8));
            multisig.changeThreshold(newThreshold);
        }
    }
}