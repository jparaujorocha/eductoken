// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title MultisigEvents
 * @dev Event declarations for the EducMultisig contract
 */
library MultisigEvents {
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
}