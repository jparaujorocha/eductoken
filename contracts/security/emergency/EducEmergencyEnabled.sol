// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../interfaces/IEducEmergencyEnabled.sol";
import "../../access/roles/EducRoles.sol";
import "./EmergencyEvents.sol";

/**
 * @title EducEmergencyEnabled
 * @dev Base contract for contracts that support emergency withdrawals
 * This contract should be inherited by contracts that need to support
 * emergency fund recovery
 */
abstract contract EducEmergencyEnabled is AccessControl, IEducEmergencyEnabled {
    using SafeERC20 for IERC20;

    // Recovery destination
    address public recoveryDestination;
    
    // Emergency recovery contract address
    address public emergencyRecoveryContract;

    /**
     * @dev Modifier to ensure only emergency recovery contract can call
     */
    modifier onlyEmergencyRecovery() {
        require(
            msg.sender == emergencyRecoveryContract && 
            emergencyRecoveryContract != address(0),
            "EducEmergencyEnabled: caller is not recovery contract"
        );
        _;
    }
    
    /**
     * @dev Modifier to ensure the address is valid (not zero)
     */
    modifier validAddress(address address_) {
        require(address_ != address(0), "EducEmergencyEnabled: zero address not allowed");
        _;
    }

    /**
     * @dev Constructor sets the recovery destination and recovery contract
     * @param _recoveryDestination Address where funds will be sent in an emergency
     * @param _emergencyRecoveryContract Address of the emergency recovery contract
     */
    constructor(address _recoveryDestination, address _emergencyRecoveryContract) {
        _validateConstructorParams(_recoveryDestination);
        
        recoveryDestination = _recoveryDestination;
        emergencyRecoveryContract = _emergencyRecoveryContract;
    }
    
    /**
     * @dev Validates constructor parameters
     * @param _recoveryDestination Recovery destination to validate
     */
    function _validateConstructorParams(address _recoveryDestination) private pure {
        require(_recoveryDestination != address(0), 
            "EducEmergencyEnabled: Invalid recovery destination");
    }

    /**
     * @dev Sets the recovery destination address
     * @param _recoveryDestination New recovery destination address
     */
    function setRecoveryDestination(address _recoveryDestination) 
        external
        onlyRole(EducRoles.ADMIN_ROLE)
        validAddress(_recoveryDestination)
    {
        address oldDestination = recoveryDestination;
        recoveryDestination = _recoveryDestination;
        
        emit EmergencyEvents.RecoveryDestinationUpdated(
            oldDestination,
            _recoveryDestination,
            block.timestamp
        );
    }
    
    /**
     * @dev Sets the emergency recovery contract
     * @param _emergencyRecoveryContract New emergency recovery contract address
     */
    function setEmergencyRecoveryContract(address _emergencyRecoveryContract)
        external
        onlyRole(EducRoles.ADMIN_ROLE)
    {
        address oldContract = emergencyRecoveryContract;
        emergencyRecoveryContract = _emergencyRecoveryContract;
        
        emit EmergencyEvents.EmergencyRecoveryContractUpdated(
            oldContract,
            _emergencyRecoveryContract,
            block.timestamp
        );
    }

    /**
     * @dev Executes an emergency withdrawal of tokens
     * @param token The token address to withdraw
     * @param amount The amount to withdraw
     * @return success Whether the operation was successful
     */
    function executeEmergencyWithdrawal(address token, uint256 amount)
        external
        override
        onlyEmergencyRecovery
        validAddress(token)
        returns (bool success)
    {
        require(amount > 0, "EducEmergencyEnabled: Invalid amount");
        
        uint256 amountToWithdraw = _getWithdrawalAmount(token, amount);
        
        if (amountToWithdraw > 0) {
            _transferTokens(token, amountToWithdraw);
            
            emit EmergencyEvents.EmergencyWithdrawal(
                token,
                amountToWithdraw,
                recoveryDestination,
                block.timestamp
            );
        }
        
        return true;
    }
    
    /**
     * @dev Gets the amount to withdraw, respecting balance limits
     * @param token Token address
     * @param requestedAmount Requested amount to withdraw
     * @return amountToWithdraw Actual amount that can be withdrawn
     */
    function _getWithdrawalAmount(address token, uint256 requestedAmount) 
        private 
        view 
        returns (uint256 amountToWithdraw) 
    {
        uint256 balance = IERC20(token).balanceOf(address(this));
        return requestedAmount > balance ? balance : requestedAmount;
    }
    
    /**
     * @dev Transfers tokens to the recovery destination
     * @param token Token address
     * @param amount Amount to transfer
     */
    function _transferTokens(address token, uint256 amount) private {
        IERC20(token).safeTransfer(recoveryDestination, amount);
    }

    /**
     * @dev Executes an emergency withdrawal of native tokens (ETH)
     * @param amount The amount to withdraw
     * @return success Whether the operation was successful
     */
    function executeEmergencyETHWithdrawal(uint256 amount)
        external
        override
        onlyEmergencyRecovery
        returns (bool success)
    {
        require(amount > 0, "EducEmergencyEnabled: Invalid amount");
        
        uint256 amountToWithdraw = _getETHWithdrawalAmount(amount);
        
        if (amountToWithdraw > 0) {
            _transferETH(amountToWithdraw);
            
            emit EmergencyEvents.EmergencyETHWithdrawal(
                amountToWithdraw,
                recoveryDestination,
                block.timestamp
            );
        }
        
        return true;
    }
    
    /**
     * @dev Gets the amount of ETH to withdraw, respecting balance limits
     * @param requestedAmount Requested amount to withdraw
     * @return amountToWithdraw Actual amount that can be withdrawn
     */
    function _getETHWithdrawalAmount(uint256 requestedAmount) 
        private 
        view 
        returns (uint256 amountToWithdraw) 
    {
        uint256 balance = address(this).balance;
        return requestedAmount > balance ? balance : requestedAmount;
    }
    
    /**
     * @dev Transfers ETH to the recovery destination
     * @param amount Amount of ETH to transfer
     */
    function _transferETH(uint256 amount) private {
        (bool sent, ) = recoveryDestination.call{value: amount}("");
        require(sent, "EducEmergencyEnabled: Failed to send ETH");
    }
    
    /**
     * @dev Function to receive ETH
     */
    receive() external payable {}
}