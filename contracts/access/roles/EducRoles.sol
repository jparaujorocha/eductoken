// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title EducRoles
 * @dev Defines role constants for the EducLearning system
 * Centralizes all role definitions to ensure consistency across the system
 */
library EducRoles {
    // Role definitions as keccak256 hashes
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant EDUCATOR_ROLE = keccak256("EDUCATOR_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    /**
     * @dev Checks if a role is a valid system role
     * @param role Role to check
     * @return isValid Whether the role is a valid system role
     */
    function isValidRole(bytes32 role) internal pure returns (bool isValid) {
        return (
            role == ADMIN_ROLE ||
            role == EDUCATOR_ROLE ||
            role == MINTER_ROLE ||
            role == PAUSER_ROLE ||
            role == UPGRADER_ROLE ||
            role == EMERGENCY_ROLE
        );
    }

    /**
     * @dev Returns the name of a role for logging and display purposes
     * @param role Role to get name for
     * @return name The string name of the role
     */
    function getRoleName(bytes32 role) internal pure returns (string memory name) {
        if (role == ADMIN_ROLE) return "Admin";
        if (role == EDUCATOR_ROLE) return "Educator";
        if (role == MINTER_ROLE) return "Minter";
        if (role == PAUSER_ROLE) return "Pauser";
        if (role == UPGRADER_ROLE) return "Upgrader";
        if (role == EMERGENCY_ROLE) return "Emergency";
        return "Unknown";
    }
    
    /**
     * @dev Gets all system roles as an array
     * @return roles Array of all system roles
     */
    function getAllRoles() internal pure returns (bytes32[] memory roles) {
        roles = new bytes32[](6);
        roles[0] = ADMIN_ROLE;
        roles[1] = EDUCATOR_ROLE;
        roles[2] = MINTER_ROLE;
        roles[3] = PAUSER_ROLE;
        roles[4] = UPGRADER_ROLE;
        roles[5] = EMERGENCY_ROLE;
        return roles;
    }
}