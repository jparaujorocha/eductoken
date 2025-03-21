// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title EducatorEvents
 * @dev Defines events for the Educator module
 */
library EducatorEvents {
    /**
     * @dev Emitted when a new educator is registered
     * @param educator Address of the registered educator
     * @param authority Address that authorized the registration
     * @param mintLimit Maximum tokens the educator can mint
     * @param timestamp When the educator was registered
     */
    event EducatorRegistered(
        address indexed educator,
        address indexed authority,
        uint256 mintLimit,
        uint256 timestamp
    );

    /**
     * @dev Emitted when an educator's status is updated
     * @param educator Address of the updated educator
     * @param isActive New active status
     * @param mintLimit New or current mint limit
     * @param timestamp When the status was updated
     */
    event EducatorStatusUpdated(
        address indexed educator,
        bool isActive,
        uint256 mintLimit,
        uint256 timestamp
    );
    
    /**
     * @dev Emitted when an educator's mint statistics are updated
     * @param educator Address of the educator
     * @param amount Amount minted in this transaction
     * @param totalMinted New total amount minted by this educator
     * @param timestamp When the mint occurred
     */
    event EducatorMintRecorded(
        address indexed educator,
        uint256 amount,
        uint256 totalMinted,
        uint256 timestamp
    );
    
    /**
     * @dev Emitted when an educator's course count is increased
     * @param educator Address of the educator
     * @param newCourseCount Updated number of courses
     * @param timestamp When the course count was updated
     */
    event EducatorCourseCountIncremented(
        address indexed educator,
        uint16 newCourseCount,
        uint256 timestamp
    );
}