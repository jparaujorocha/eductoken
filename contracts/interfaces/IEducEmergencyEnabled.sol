// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IEducEmergencyEnabled
 * @dev Interface for contracts that support emergency withdrawal functionality
 */
interface IEducEmergencyEnabled {
    /**
     * @dev Executes an emergency withdrawal of tokens
     * @param token The token address to withdraw
     * @param amount The amount to withdraw
     * @return success Whether the operation was successful
     */
    function executeEmergencyWithdrawal(address token, uint256 amount) external returns (bool success);
    
    /**
     * @dev Executes an emergency withdrawal of native tokens (ETH)
     * @param amount The amount to withdraw
     * @return success Whether the operation was successful
     */
    function executeEmergencyETHWithdrawal(uint256 amount) external returns (bool success);
}