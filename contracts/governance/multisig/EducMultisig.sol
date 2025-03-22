// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../../access/roles/EducRoles.sol";
import "../../config/constants/SystemConstants.sol";
import "../../interfaces/IEducMultisig.sol";
import "./MultisigEvents.sol";

/**
 * @title EducMultisig
 * @dev Advanced multi-signature governance mechanism with comprehensive validation
 */
contract EducMultisig is AccessControl, ReentrancyGuard, IEducMultisig {
    uint8 public constant MAX_SIGNERS = 10;
    uint8 public constant MIN_SIGNERS = 1;

    address[] public signers;
    uint8 public threshold;
    uint256 public proposalCount;
    address public authority;

    mapping(address => bool) public isSigner;

    constructor(
        address[] memory _signers,
        uint8 _threshold,
        address admin
    ) {
        _validateConstructorParams(_signers, _threshold, admin);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(EducRoles.ADMIN_ROLE, admin);

        _initializeSigners(_signers);

        threshold = _threshold;
        authority = admin;
        proposalCount = 0;

        emit MultisigEvents.MultisigCreated(address(this), _signers, _threshold, block.timestamp);
    }

    function addSigner(address newSigner)
        external
        onlyRole(EducRoles.ADMIN_ROLE)
        nonReentrant
    {
        _validateNewSigner(newSigner);

        signers.push(newSigner);
        isSigner[newSigner] = true;
        _grantRole(EducRoles.ADMIN_ROLE, newSigner);

        _adjustThresholdIfNeeded();

        emit MultisigEvents.SignerAdded(newSigner, block.timestamp);
    }

    function removeSigner(address signerToRemove)
        external
        onlyRole(EducRoles.ADMIN_ROLE)
        nonReentrant
    {
        _validateSignerRemoval(signerToRemove);

        _removeSignerFromList(signerToRemove);

        isSigner[signerToRemove] = false;
        _revokeRole(EducRoles.ADMIN_ROLE, signerToRemove);

        emit MultisigEvents.SignerRemoved(signerToRemove, block.timestamp);
    }

    function changeThreshold(uint8 newThreshold)
        external
        onlyRole(EducRoles.ADMIN_ROLE)
        nonReentrant
    {
        require(newThreshold >= 1 && newThreshold <= signers.length, "EducMultisig: Invalid threshold");

        uint8 oldThreshold = threshold;
        threshold = newThreshold;

        emit MultisigEvents.ThresholdChanged(oldThreshold, newThreshold, block.timestamp);
    }

    function incrementProposalCount()
        external
        onlyRole(EducRoles.ADMIN_ROLE)
        returns (uint256)
    {
        proposalCount++;
        return proposalCount;
    }

    function getSigners() external view returns (address[] memory) {
        return signers;
    }

    function getSignerCount() external view returns (uint256) {
        return signers.length;
    }

    function _validateConstructorParams(address[] memory _signers, uint8 _threshold, address admin) private pure {
        require(admin != address(0), "EducMultisig: Invalid admin");
        require(_signers.length >= MIN_SIGNERS, "EducMultisig: Insufficient signers");
        require(_signers.length <= MAX_SIGNERS, "EducMultisig: Too many signers");
        require(_threshold >= 1 && _threshold <= _signers.length, "EducMultisig: Invalid threshold");
    }

    function _initializeSigners(address[] memory _signers) private {
        for (uint256 i = 0; i < _signers.length; i++) {
            require(_signers[i] != address(0), "EducMultisig: Invalid signer address");
            for (uint256 j = i + 1; j < _signers.length; j++) {
                require(_signers[i] != _signers[j], "EducMultisig: Duplicate signer");
            }
            signers.push(_signers[i]);
            isSigner[_signers[i]] = true;
            _grantRole(EducRoles.ADMIN_ROLE, _signers[i]);
        }
    }

    function _validateNewSigner(address newSigner) private view {
        require(newSigner != address(0), "EducMultisig: Invalid signer");
        require(!isSigner[newSigner], "EducMultisig: Signer already exists");
        require(signers.length < MAX_SIGNERS, "EducMultisig: Max signers reached");
    }

    function _adjustThresholdIfNeeded() private {
        if (threshold > signers.length) {
            uint8 oldThreshold = threshold;
            threshold = uint8(signers.length);
            emit MultisigEvents.ThresholdChanged(oldThreshold, threshold, block.timestamp);
        }
    }

    function _validateSignerRemoval(address signerToRemove) private view {
        require(isSigner[signerToRemove], "EducMultisig: Signer not found");
        require(signers.length > threshold, "EducMultisig: Cannot remove signer");
    }

    function _removeSignerFromList(address signerToRemove) private {
        for (uint256 i = 0; i < signers.length; i++) {
            if (signers[i] == signerToRemove) {
                signers[i] = signers[signers.length - 1];
                signers.pop();
                break;
            }
        }
    }
}