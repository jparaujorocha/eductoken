// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IEducMultisig {
    function addSigner(address newSigner) external;
    function removeSigner(address signerToRemove) external;
    function changeThreshold(uint8 newThreshold) external;
    function incrementProposalCount() external returns (uint256);
    
    function getSigners() external view returns (address[] memory);
    function getSignerCount() external view returns (uint256);
    
    function isSigner(address account) external view returns (bool);
    
    function threshold() external view returns (uint8);
}