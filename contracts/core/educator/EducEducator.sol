// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../../access/roles/EducRoles.sol";
import "../../config/constants/SystemConstants.sol";
import "../../interfaces/IEducEducator.sol";
import "./EducatorEvents.sol";
import "./types/EducatorTypes.sol";

/**
 * @title EducEducator
 * @dev Manages educator accounts and permissions in the EducLearning system
 */
contract EducEducator is AccessControl, Pausable, ReentrancyGuard, IEducEducator {
    // Storage
    mapping(address => EducatorTypes.Educator) private educators;
    uint16 public totalEducators;

    // Modifiers
    modifier educatorExists(address educator) {
        require(educators[educator].educatorAddress != address(0), "EducEducator: educator does not exist");
        _;
    }
    
    modifier educatorNotExists(address educator) {
        require(educators[educator].educatorAddress == address(0), "EducEducator: educator already registered");
        _;
    }
    
    modifier validAddress(address account) {
        require(account != address(0), "EducEducator: address cannot be zero");
        _;
    }

    /**
     * @dev Constructor that sets up the admin role
     * @param admin The address that will be granted the admin role
     */
    constructor(address admin) validAddress(admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(EducRoles.ADMIN_ROLE, admin);
        totalEducators = 0;
    }

    /**
     * @dev Registers a new educator with structured parameters
     * @param params Registration parameters (educator address and mint limit)
     */
    function registerEducator(EducatorTypes.EducatorRegistrationParams calldata params)
        external
        override
        onlyRole(EducRoles.ADMIN_ROLE)
        whenNotPaused
        nonReentrant
        validAddress(params.educatorAddress)
        educatorNotExists(params.educatorAddress)
    {
        _validateMintLimit(params.mintLimit);
        _registerEducator(params.educatorAddress, params.mintLimit);
    }
    
    /**
     * @dev Legacy method for compatibility - registers a new educator
     * @param educator Address of the educator to register
     * @param mintLimit Maximum tokens the educator can mint
     */
    function registerEducator(address educator, uint256 mintLimit)
        external
        override
        onlyRole(EducRoles.ADMIN_ROLE)
        whenNotPaused
        nonReentrant
        validAddress(educator)
        educatorNotExists(educator)
    {
        _validateMintLimit(mintLimit);
        _registerEducator(educator, mintLimit);
    }
    
    /**
     * @dev Validates the mint limit
     * @param mintLimit Mint limit to validate
     */
    function _validateMintLimit(uint256 mintLimit) private pure {
        require(mintLimit > 0 && mintLimit <= SystemConstants.MAX_MINT_AMOUNT, 
            "EducEducator: invalid mint limit");
    }
    
    /**
     * @dev Internal implementation of educator registration
     * @param educator Address of the educator
     * @param mintLimit Maximum tokens the educator can mint
     */
    function _registerEducator(address educator, uint256 mintLimit) private {
        require(totalEducators < type(uint16).max, "EducEducator: max educators limit reached");
        
        uint256 currentTime = block.timestamp;

        educators[educator] = EducatorTypes.Educator({
            educatorAddress: educator,
            authorityAddress: msg.sender,
            mintLimit: mintLimit,
            totalMinted: 0,
            courseCount: 0,
            isActive: true,
            createdAt: currentTime,
            lastUpdatedAt: currentTime,
            lastMintTime: 0
        });

        totalEducators++;

        emit EducatorEvents.EducatorRegistered(
            educator,
            msg.sender,
            mintLimit,
            currentTime
        );
    }

    /**
     * @dev Updates an educator's status with structured parameters
     * @param params Status update parameters (educator, active status, mint limit)
     */
    function setEducatorStatus(EducatorTypes.EducatorStatusUpdateParams calldata params)
        external
        override
        onlyRole(EducRoles.ADMIN_ROLE)
        nonReentrant
        validAddress(params.educatorAddress)
        educatorExists(params.educatorAddress)
    {
        _updateEducatorStatus(
            params.educatorAddress,
            params.isActive,
            params.newMintLimit
        );
    }
    
    /**
     * @dev Legacy method for compatibility - updates an educator's status
     * @param educator Address of the educator to update
     * @param isActive New active status
     * @param newMintLimit Optional new mint limit (0 to keep current)
     */
    function setEducatorStatus(address educator, bool isActive, uint256 newMintLimit)
        external
        override
        onlyRole(EducRoles.ADMIN_ROLE)
        nonReentrant
        validAddress(educator)
        educatorExists(educator)
    {
        _updateEducatorStatus(educator, isActive, newMintLimit);
    }
    
    /**
     * @dev Internal implementation of educator status update
     * @param educator Address of the educator
     * @param isActive New active status
     * @param newMintLimit Optional new mint limit (0 to keep current)
     */
    function _updateEducatorStatus(
        address educator,
        bool isActive,
        uint256 newMintLimit
    ) private {
        uint256 currentTime = block.timestamp;
        EducatorTypes.Educator storage educatorData = educators[educator];
        
        educatorData.isActive = isActive;
        
        if (newMintLimit > 0 && newMintLimit <= SystemConstants.MAX_MINT_AMOUNT) {
            educatorData.mintLimit = newMintLimit;
        }
        
        educatorData.lastUpdatedAt = currentTime;

        emit EducatorEvents.EducatorStatusUpdated(
            educator,
            isActive,
            educatorData.mintLimit,
            currentTime
        );
    }

    /**
     * @dev Updates educator's mint statistics
     * @param educator Address of the educator
     * @param amount Amount that was minted
     */
    function recordMint(address educator, uint256 amount) 
        external 
        override 
        nonReentrant
        onlyRole(EducRoles.ADMIN_ROLE)
        educatorExists(educator)
    {
        EducatorTypes.Educator storage educatorData = educators[educator];

        require(educatorData.isActive, "EducEducator: educator is not active");

        require(
            educatorData.totalMinted + amount <= educatorData.mintLimit,
            "EducEducator: mint limit exceeded"
        );

        educatorData.totalMinted += amount;
        educatorData.lastMintTime = block.timestamp;
        
        emit EducatorEvents.EducatorMintRecorded(
            educator,
            amount,
            educatorData.totalMinted,
            block.timestamp
        );
    }

    /**
     * @dev Increases an educator's course count
     * @param educator Address of the educator
     */
    function incrementCourseCount(address educator) 
        external 
        override 
        nonReentrant
        onlyRole(EducRoles.ADMIN_ROLE)
        educatorExists(educator)
    {
        EducatorTypes.Educator storage educatorData = educators[educator];
        require(educatorData.courseCount < type(uint16).max, "EducEducator: max courses reached");
        
        educatorData.courseCount++;
        
        emit EducatorEvents.EducatorCourseCountIncremented(
            educator,
            educatorData.courseCount,
            block.timestamp
        );
    }

    /**
     * @dev Checks if an address is a registered and active educator
     * @param educator Address to check
     * @return isActive True if address is an active educator
     */
    function isActiveEducator(address educator) 
        external 
        view 
        override 
        returns (bool isActive) 
    {
        return educators[educator].educatorAddress != address(0) && 
               educators[educator].isActive;
    }

    /**
     * @dev Gets an educator's mint limit
     * @param educator Address of the educator
     * @return mintLimit The educator's mint limit
     */
    function getEducatorMintLimit(address educator) 
        external 
        view 
        override
        educatorExists(educator)
        returns (uint256 mintLimit) 
    {
        return educators[educator].mintLimit;
    }

    /**
     * @dev Gets an educator's total minted amount
     * @param educator Address of the educator
     * @return totalMinted The educator's total minted amount
     */
    function getEducatorTotalMinted(address educator) 
        external 
        view 
        override
        educatorExists(educator)
        returns (uint256 totalMinted) 
    {
        return educators[educator].totalMinted;
    }
    
    /**
     * @dev Gets all information about an educator
     * @param educator Address of the educator
     * @return educatorInfo The educator's data structure
     */
    function getEducatorInfo(address educator) 
        external 
        view 
        override
        educatorExists(educator)
        returns (EducatorTypes.Educator memory educatorInfo) 
    {
        return educators[educator];
    }
    
    /**
     * @dev Gets the total number of registered educators
     * @return count The number of educators registered in the system
     */
    function getTotalEducators() 
        external 
        view 
        override
        returns (uint16 count) 
    {
        return totalEducators;
    }
    
    /**
     * @dev Pauses educator management functions
     */
    function pause() external onlyRole(EducRoles.ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Unpauses educator management functions
     */
    function unpause() external onlyRole(EducRoles.ADMIN_ROLE) {
        _unpause();
    }
}