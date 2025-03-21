// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../access/EducRoles.sol";

/**
 * @title EducMultisig
 * @dev Implements a multi-signature governance mechanism
 */
contract EducMultisig is AccessControl, ReentrancyGuard {
    // Constants
    uint8 public constant MAX_SIGNERS = 10;
    
    // State variables
    address[] public signers;
    uint8 public threshold;
    uint256 public proposalCount;
    address public authority;
    
    // Events
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
     * @dev Constructor that sets up the multisig configuration
     * @param _signers Array of signer addresses
     * @param _threshold Minimum number of approvals needed
     * @param admin Admin address
     */
    constructor(
        address[] memory _signers,
        uint8 _threshold,
        address admin
    ) {
        require(_signers.length > 0, "EducMultisig: no signers provided");
        require(_signers.length <= MAX_SIGNERS, "EducMultisig: too many signers");
        require(_threshold > 0 && _threshold <= _signers.length, "EducMultisig: invalid threshold");
        require(admin != address(0), "EducMultisig: admin cannot be zero address");
        
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole(EducRoles.ADMIN_ROLE, admin);
        
        // Check for duplicates and zero addresses
        for (uint256 i = 0; i < _signers.length; i++) {
            require(_signers[i] != address(0), "EducMultisig: signer cannot be zero address");
            
            for (uint256 j = i + 1; j < _signers.length; j++) {
                require(_signers[i] != _signers[j], "EducMultisig: duplicate signer");
            }
            
            signers.push(_signers[i]);
            _grantRole(EducRoles.ADMIN_ROLE, _signers[i]);
        }
        
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
     * @dev Adds a new signer to the multisig
     * @param newSigner Address of the signer to add
     */
    function addSigner(address newSigner) external onlyRole(EducRoles.ADMIN_ROLE) nonReentrant {
        require(newSigner != address(0), "EducMultisig: signer cannot be zero address");
        require(signers.length < MAX_SIGNERS, "EducMultisig: max signers reached");
        
        // Check for duplicates
        for (uint256 i = 0; i < signers.length; i++) {
            require(signers[i] != newSigner, "EducMultisig: signer already exists");
        }
        
        signers.push(newSigner);
        _grantRole(EducRoles.ADMIN_ROLE, newSigner);
        
        emit SignerAdded(newSigner, block.timestamp);
    }
    
    /**
     * @dev Removes a signer from the multisig
     * @param signerToRemove Address of the signer to remove
     */
    function removeSigner(address signerToRemove) external onlyRole(EducRoles.ADMIN_ROLE) nonReentrant {
        require(signers.length > threshold, "EducMultisig: cannot remove signer when threshold cannot be met");
        
        bool found = false;
        uint256 signerIndex = 0;
        
        // Find the signer
        for (uint256 i = 0; i < signers.length; i++) {
            if (signers[i] == signerToRemove) {
                found = true;
                signerIndex = i;
                break;
            }
        }
        
        require(found, "EducMultisig: signer does not exist");
        
        // Remove by swapping with the last element and popping
        signers[signerIndex] = signers[signers.length - 1];
        signers.pop();
        
        _revokeRole(EducRoles.ADMIN_ROLE, signerToRemove);
        
        // Adjust threshold if needed
        if (threshold > signers.length) {
            uint8 oldThreshold = threshold;
            threshold = uint8(signers.length);
            
            emit ThresholdChanged(oldThreshold, threshold, block.timestamp);
        }
        
        emit SignerRemoved(signerToRemove, block.timestamp);
    }
    
    /**
     * @dev Changes the threshold for approvals
     * @param newThreshold New threshold value
     */
    function changeThreshold(uint8 newThreshold) external onlyRole(EducRoles.ADMIN_ROLE) nonReentrant {
        require(newThreshold > 0, "EducMultisig: threshold must be positive");
        require(newThreshold <= signers.length, "EducMultisig: threshold cannot exceed signer count");
        
        uint8 oldThreshold = threshold;
        threshold = newThreshold;
        
        emit ThresholdChanged(oldThreshold, newThreshold, block.timestamp);
    }
    
    /**
     * @dev Checks if an address is a signer
     * @param account Address to check
     * @return bool True if the address is a signer
     */
    function isSigner(address account) external view returns (bool) {
        for (uint256 i = 0; i < signers.length; i++) {
            if (signers[i] == account) {
                return true;
            }
        }
        return false;
    }
    
    /**
     * @dev Gets all current signers
     * @return address[] Array of signer addresses
     */
    function getSigners() external view returns (address[] memory) {
        return signers;
    }
    
    /**
     * @dev Gets the current number of signers
     * @return uint256 Number of signers
     */
    function getSignerCount() external view returns (uint256) {
        return signers.length;
    }
}