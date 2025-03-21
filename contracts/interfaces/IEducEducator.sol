// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../core/educator/types/EducatorTypes.sol";

/**
 * @title IEducEducator
 * @dev Interface for the EducEducator contract
 */
interface IEducEducator {
    /**
     * @dev Registers a new educator
     * @param params Registration parameters (educator address and mint limit)
     */
    function registerEducator(EducatorTypes.EducatorRegistrationParams calldata params) external;

    /**
     * @dev Legacy method for compatibility - registers a new educator
     * @param educator Address of the educator to register
     * @param mintLimit Maximum tokens the educator can mint
     */
    function registerEducator(address educator, uint256 mintLimit) external;

    /**
     * @dev Updates an educator's status
     * @param params Status update parameters (educator address, active status, mint limit)
     */
    function setEducatorStatus(EducatorTypes.EducatorStatusUpdateParams calldata params) external;

    /**
     * @dev Legacy method for compatibility - updates an educator's status
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
     * @return isActive True if address is an active educator
     */
    function isActiveEducator(address educator) external view returns (bool isActive);

    /**
     * @dev Gets an educator's mint limit
     * @param educator Address of the educator
     * @return mintLimit The educator's mint limit
     */
    function getEducatorMintLimit(address educator) external view returns (uint256 mintLimit);

    /**
     * @dev Gets an educator's total minted amount
     * @param educator Address of the educator
     * @return totalMinted The educator's total minted amount
     */
    function getEducatorTotalMinted(address educator) external view returns (uint256 totalMinted);
    
    /**
     * @dev Gets all information about an educator
     * @param educator Address of the educator
     * @return educatorInfo The educator's data structure
     */
    function getEducatorInfo(address educator) external view returns (EducatorTypes.Educator memory educatorInfo);
    
    /**
     * @dev Gets the total number of registered educators
     * @return count The number of educators registered in the system
     */
    function getTotalEducators() external view returns (uint16 count);
}