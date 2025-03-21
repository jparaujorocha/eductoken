// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../access/roles/EducRoles.sol";
import "../interfaces/IEducToken.sol";
import "./EducVesting.sol";
import "./VestingEvents.sol";

/**
 * @title EducVestingFactory
 * @dev Factory contract to create new vesting contracts for different tokens and beneficiaries
 */
contract EducVestingFactory is AccessControl {
    // Maps token addresses to their vesting contracts
    mapping(address => address[]) public vestingContracts;
    
    // Array of all created vesting contracts
    address[] public allVestingContracts;
    
    /**
     * @dev Constructor sets up admin role
     * @param admin Administrator address
     */
    constructor(address admin) {
        require(admin != address(0), "EducVestingFactory: Admin cannot be zero address");
        
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(EducRoles.ADMIN_ROLE, admin);
    }
    
    /**
     * @dev Creates a new vesting contract for a specific token
     * @param token Address of the token to be vested
     * @param treasury Address where revoked tokens will be sent
     * @return vestingContract Address of the created vesting contract
     */
    function createVestingContract(address token, address treasury) 
        external 
        onlyRole(EducRoles.ADMIN_ROLE) 
        returns (address vestingContract) 
    {
        require(token != address(0), "EducVestingFactory: Token cannot be zero address");
        require(treasury != address(0), "EducVestingFactory: Treasury cannot be zero address");
        
        // Create new vesting contract
        EducVesting newVesting = new EducVesting(token, treasury, msg.sender);
        
        // Store the vesting contract
        vestingContracts[token].push(address(newVesting));
        allVestingContracts.push(address(newVesting));
        
        // Emit event
        emit VestingEvents.VestingContractCreated(
            address(newVesting),
            msg.sender,
            token
        );
        
        return address(newVesting);
    }
    
    /**
     * @dev Gets all vesting contracts created for a specific token
     * @param token Address of the token
     * @return contracts Array of vesting contract addresses
     */
    function getVestingContractsForToken(address token) 
        external 
        view 
        returns (address[] memory contracts) 
    {
        return vestingContracts[token];
    }
    
    /**
     * @dev Gets all vesting contracts created by this factory
     * @return contracts Array of all vesting contract addresses
     */
    function getAllVestingContracts() 
        external 
        view 
        returns (address[] memory contracts) 
    {
        return allVestingContracts;
    }
    
    /**
     * @dev Gets the number of vesting contracts created for a specific token
     * @param token Address of the token
     * @return count Number of vesting contracts
     */
    function getVestingContractsCountForToken(address token) 
        external 
        view 
        returns (uint256 count) 
    {
        return vestingContracts[token].length;
    }
    
    /**
     * @dev Gets the total number of vesting contracts created
     * @return count Total number of vesting contracts
     */
    function getTotalVestingContractsCount() 
        external 
        view 
        returns (uint256 count) 
    {
        return allVestingContracts.length;
    }
}