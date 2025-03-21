// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IEducToken
 * @dev Interface for the EducToken contract with enhanced educational reward functionality
 */
interface IEducToken is IERC20 {
    /**
     * @dev Mints new tokens to an address
     * @param to The address that will receive the minted tokens
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) external;

    /**
     * @dev Mints tokens as educational rewards with detailed tracking
     * @param student The student address that will receive the reward
     * @param amount The amount of tokens to mint as reward
     * @param reason The educational reason for the reward
     */
    function mintReward(address student, uint256 amount, string calldata reason) external;
    
    /**
     * @dev Batch mints tokens as educational rewards to multiple students
     * @param students Array of student addresses
     * @param amounts Array of token amounts
     * @param reasons Array of educational reasons
     */
    function batchMintReward(
        address[] calldata students,
        uint256[] calldata amounts,
        string[] calldata reasons
    ) external;

    /**
     * @dev Burns tokens from the caller's account
     * @param amount The amount of tokens to burn
     */
    function burn(uint256 amount) external;

    /**
     * @dev Burns tokens from inactive accounts
     * @param from The address from which to burn tokens
     * @param amount The amount of tokens to burn
     * @param reason The reason for burning tokens
     */
    function burnFromInactive(address from, uint256 amount, string calldata reason) external;

    /**
     * @dev Transfer tokens from the caller to another account
     * @param to The address to transfer to
     * @param amount The amount to transfer
     * @return bool True if the transfer was successful
     */
    function transfer(address to, uint256 amount) external override returns (bool);

    /**
     * @dev Transfer tokens from one account to another
     * @param from The address to transfer from
     * @param to The address to transfer to
     * @param amount The amount to transfer
     * @return bool True if the transfer was successful
     */
    function transferFrom(address from, address to, uint256 amount) external override returns (bool);
    
    /**
     * @dev Gets whether an account is currently inactive
     * @param account The account to check
     * @return bool True if the account is inactive
     */
    function isAccountInactive(address account) external view returns (bool);
    
    /**
     * @dev Gets the remaining daily minting capacity
     * @return uint256 The amount of tokens that can still be minted today
     */
    function getDailyMintingRemaining() external view returns (uint256);

    // Events
    event TokensMinted(address indexed to, uint256 amount, address indexed minter);
    event TokensBurned(address indexed from, uint256 amount);
    event TokensBurnedFrom(address indexed from, uint256 amount, address indexed burner, string reason);
    event RewardIssued(address indexed student, uint256 amount, string reason);
    event StudentContractSet(address indexed studentContract);
}