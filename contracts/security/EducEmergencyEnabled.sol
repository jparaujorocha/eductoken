// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IEducEmergencyEnabled.sol";
import "../access/EducRoles.sol";

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

    // Events
    event EmergencyWithdrawal(
        address indexed token,
        uint256 amount,
        address indexed destination,
        uint256 timestamp
    );

    event EmergencyETHWithdrawal(
        uint256 amount,
        address indexed destination,
        uint256 timestamp
    );

    event RecoveryDestinationUpdated(
        address previousDestination,
        address newDestination,
        uint256 timestamp
    );
    
    event EmergencyRecoveryContractUpdated(
        address previousContract,
        address newContract,
        uint256 timestamp
    );

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
     * @dev Constructor sets the recovery destination and recovery contract
     * @param _recoveryDestination Address where funds will be sent in an emergency
     * @param _emergencyRecoveryContract Address of the emergency recovery contract
     */
    constructor(address _recoveryDestination, address _emergencyRecoveryContract) {
        require(_recoveryDestination != address(0), "EducEmergencyEnabled: Invalid recovery destination");
        
        recoveryDestination = _recoveryDestination;
        emergencyRecoveryContract = _emergencyRecoveryContract;
    }

    /**
     * @dev Sets the recovery destination address
     * @param _recoveryDestination New recovery destination address
     */
    function setRecoveryDestination(address _recoveryDestination) 
        external
        onlyRole(EducRoles.ADMIN_ROLE)
    {
        require(_recoveryDestination != address(0), "EducEmergencyEnabled: Invalid recovery destination");
        
        address oldDestination = recoveryDestination;
        recoveryDestination = _recoveryDestination;
        
        emit RecoveryDestinationUpdated(
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
        
        emit EmergencyRecoveryContractUpdated(
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
        returns (bool success)
    {
        require(token != address(0), "EducEmergencyEnabled: Invalid token address");
        require(amount > 0, "EducEmergencyEnabled: Invalid amount");
        
        uint256 balance = IERC20(token).balanceOf(address(this));
        uint256 amountToWithdraw = amount > balance ? balance : amount;
        
        if (amountToWithdraw > 0) {
            IERC20(token).safeTransfer(recoveryDestination, amountToWithdraw);
            
            emit EmergencyWithdrawal(
                token,
                amountToWithdraw,
                recoveryDestination,
                block.timestamp
            );
        }
        
        return true;
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
        
        uint256 balance = address(this).balance;
        uint256 amountToWithdraw = amount > balance ? balance : amount;
        
        if (amountToWithdraw > 0) {
            (bool sent, ) = recoveryDestination.call{value: amountToWithdraw}("");
            require(sent, "EducEmergencyEnabled: Failed to send ETH");
            
            emit EmergencyETHWithdrawal(
                amountToWithdraw,
                recoveryDestination,
                block.timestamp
            );
        }
        
        return true;
    }
    
    /**
     * @dev Function to receive ETH
     */
    receive() external payable {}
}