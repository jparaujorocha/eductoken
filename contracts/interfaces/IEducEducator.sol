// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IEducEducator
 * @dev Interface for the EducEducator contract
 */
interface IEducEducator {
    /**
     * @dev Registers a new educator
     * @param educator Address of the educator to register
     * @param mintLimit Maximum tokens the educator can mint
     */
    function registerEducator(address educator, uint256 mintLimit) external;

    /**
     * @dev Updates an educator's status
     * @param educator Address of the educator to update
     * @param isActive New active status
     * @param newMintLimit Optional new mint limit (0 to keep current)
     */
    function setEducatorStatus(address educator, bool isActive, uint256 newMintLimit) external;

    /**
     * @dev Updates educator's mint statistics
     * @param educator Address of the educator
     * @param amount Amount that was minted
     */
    function recordMint(address educator, uint256 amount) external;

    /**
     * @dev Increases an educator's course count
     * @param educator Address of the educator
     */
    function incrementCourseCount(address educator) external;

    /**
     * @dev Checks if an address is a registered and active educator
     * @param educator Address to check
     * @return bool True if address is an active educator
     */
    function isActiveEducator(address educator) external view returns (bool);

    /**
     * @dev Gets an educator's mint limit
     * @param educator Address of the educator
     * @return uint256 The educator's mint limit
     */
    function getEducatorMintLimit(address educator) external view returns (uint256);

    /**
     * @dev Gets an educator's total minted amount
     * @param educator Address of the educator
     * @return uint256 The educator's total minted amount
     */
    function getEducatorTotalMinted(address educator) external view returns (uint256);
}