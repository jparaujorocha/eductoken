// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../../access/roles/EducRoles.sol";
import "../../config/constants/SystemConstants.sol";
import "../../interfaces/IEducMultisig.sol";
import "./MultisigEvents.sol";
import "./types/MultisigTypes.sol";

/**
 * @title EducMultisig
 * @dev Advanced multi-signature governance mechanism with comprehensive validation
 */
contract EducMultisig is AccessControl, ReentrancyGuard {
    // Multisig configuration constraints
    uint8 public constant MAX_SIGNERS = 10;
    uint8 public constant MIN_SIGNERS = 1;
    
    // Multisig state tracking
    address[] public signers;
    uint8 public threshold;
    uint256 public proposalCount;
    address public authority;
    
    // Signer management tracking
    mapping(address => bool) public isSigner;
    
    // Events with comprehensive logging
    event MultisigCreated(
        address indexed multisig,
        address[] signers,
        uint8 threshold,
        uint256 timestamp
    );
    
    event SignerAdded(
        address indexed signer,
        uint256 timestamp
    );
    
    event SignerRemoved(
        address indexed signer,
        uint256 timestamp
    );
    
    event ThresholdChanged(
        uint8 oldThreshold,
        uint8 newThreshold,
        uint256 timestamp
    );

    /**
     * @dev Constructor sets up multisig configuration with robust validation
     * @param _signers Initial set of signers
     * @param _threshold Minimum approvals required
     * @param admin Administrator address
     */
    constructor(
        address[] memory _signers,
        uint8 _threshold,
        address admin
    ) {
        // Validate input parameters
        require(admin != address(0), "EducMultisig: Invalid admin");
        require(_signers.length >= MIN_SIGNERS, "EducMultisig: Insufficient signers");
        require(_signers.length <= MAX_SIGNERS, "EducMultisig: Too many signers");
        
        // Validate threshold
        require(
            _threshold >= 1 && 
            _threshold <= _signers.length, 
            "EducMultisig: Invalid threshold"
        );

        // Grant roles and validate signers
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(EducRoles.ADMIN_ROLE, admin);
        
        // Validate and add unique signers
        for (uint256 i = 0; i < _signers.length; i++) {
            require(_signers[i] != address(0), "EducMultisig: Invalid signer address");
            
            // Check for duplicate signers
            for (uint256 j = i + 1; j < _signers.length; j++) {
                require(_signers[i] != _signers[j], "EducMultisig: Duplicate signer");
            }
            
            signers.push(_signers[i]);
            isSigner[_signers[i]] = true;
            _grantRole(EducRoles.ADMIN_ROLE, _signers[i]);
        }
        
        // Set core configuration
        threshold = _threshold;
        authority = admin;
        proposalCount = 0;

        emit MultisigCreated(
            address(this),
            _signers,
            _threshold,
            block.timestamp
        );
    }

    /**
     * @dev Adds a new signer with comprehensive validation
     * @param newSigner Address of the new signer
     */
    function addSigner(address newSigner) 
        external 
        onlyRole(EducRoles.ADMIN_ROLE) 
        nonReentrant
    {
        require(newSigner != address(0), "EducMultisig: Invalid signer");
        require(!isSigner[newSigner], "EducMultisig: Signer already exists");
        require(signers.length < MAX_SIGNERS, "EducMultisig: Max signers reached");

        signers.push(newSigner);
        isSigner[newSigner] = true;
        _grantRole(EducRoles.ADMIN_ROLE, newSigner);

        // Adjust threshold if necessary
        if (threshold > signers.length) {
            uint8 oldThreshold = threshold;
            threshold = uint8(signers.length);
            
            emit ThresholdChanged(
                oldThreshold, 
                threshold, 
                block.timestamp
            );
        }

        emit SignerAdded(newSigner, block.timestamp);
    }

    /**
     * @dev Removes a signer with threshold protection
     * @param signerToRemove Address of the signer to remove
     */
    function removeSigner(address signerToRemove) 
        external 
        onlyRole(EducRoles.ADMIN_ROLE) 
        nonReentrant
    {
        require(isSigner[signerToRemove], "EducMultisig: Signer not found");
        require(signers.length > threshold, "EducMultisig: Cannot remove signer");

        // Remove signer
        for (uint256 i = 0; i < signers.length; i++) {
            if (signers[i] == signerToRemove) {
                signers[i] = signers[signers.length - 1];
                signers.pop();
                break;
            }
        }

        isSigner[signerToRemove] = false;
        _revokeRole(EducRoles.ADMIN_ROLE, signerToRemove);

        emit SignerRemoved(signerToRemove, block.timestamp);
    }

    /**
     * @dev Changes the approval threshold
     * @param newThreshold New threshold value
     */
    function changeThreshold(uint8 newThreshold) 
        external 
        onlyRole(EducRoles.ADMIN_ROLE) 
        nonReentrant
    {
        require(
            newThreshold >= 1 && 
            newThreshold <= signers.length, 
            "EducMultisig: Invalid threshold"
        );

        uint8 oldThreshold = threshold;
        threshold = newThreshold;

        emit ThresholdChanged(
            oldThreshold, 
            newThreshold, 
            block.timestamp
        );
    }

    /**
     * @dev Increments proposal counter
     * @return Current proposal count
     */
    function incrementProposalCount() 
        external 
        onlyRole(EducRoles.ADMIN_ROLE) 
        returns (uint256) 
    {
        proposalCount++;
        return proposalCount;
    }

    /**
     * @dev Retrieves current signers
     * @return Array of current signers
     */
    function getSigners() 
        external 
        view 
        returns (address[] memory) 
    {
        return signers;
    }

    /**
     * @dev Gets the current number of signers
     * @return Number of signers
     */
    function getSignerCount() 
        external 
        view 
        returns (uint256) 
    {
        return signers.length;
    }
}