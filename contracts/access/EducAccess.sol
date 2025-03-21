// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./EducRoles.sol";

/**
 * @title EducAccess
 * @dev Manages role-based access control for the EducLearning system
 */
contract EducAccess is AccessControl, Pausable {
    /**
     * @dev Constructor that sets up the admin role
     * @param admin The address that will be granted the admin role
     */
    constructor(address admin) {
        require(admin != address(0), "EducAccess: admin cannot be zero address");

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(EducRoles.ADMIN_ROLE, admin);
        _grantRole(EducRoles.PAUSER_ROLE, admin);
        _grantRole(EducRoles.UPGRADER_ROLE, admin);
        _grantRole(EducRoles.EMERGENCY_ROLE, admin);
    }

    /**
     * @dev Grants a role to an account
     * @param role The role to grant
     * @param account The account to grant the role to
     */
    function grantRole(bytes32 role, address account) 
        public 
        override 
        onlyRole(getRoleAdmin(role)) 
    {
        super.grantRole(role, account);
        emit RoleGranted(role, account, msg.sender);
    }

    /**
     * @dev Revokes a role from an account
     * @param role The role to revoke
     * @param account The account to revoke the role from
     */
    function revokeRole(bytes32 role, address account) 
        public 
        override 
        onlyRole(getRoleAdmin(role)) 
    {
        super.revokeRole(role, account);
        emit RoleRevoked(role, account, msg.sender);
    }

    /**
     * @dev Pauses all operations
     */
    function pause() external onlyRole(EducRoles.PAUSER_ROLE) {
        _pause();
    }

    /**
     * @dev Unpauses all operations
     */
    function unpause() external onlyRole(EducRoles.PAUSER_ROLE) {
        _unpause();
    }
}