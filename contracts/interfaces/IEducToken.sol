// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IEducToken
 * @dev Interface for the EducToken contract
 */
interface IEducToken is IERC20 {
    /**
     * @dev Mints new tokens to an address
     * @param to The address that will receive the minted tokens
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) external;

    /**
     * @dev Burns tokens from the caller's account
     * @param amount The amount of tokens to burn
     */
    function burn(uint256 amount) external;

    /**
     * @dev Burns tokens from a specific account (admin function for expired tokens)
     * @param from The address from which to burn tokens
     * @param amount The amount of tokens to burn
     * @param reason The reason for burning tokens
     */
    function burnFrom(address from, uint256 amount, string calldata reason) external;

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

    // Events
    event TokensMinted(address indexed to, uint256 amount, address indexed minter);
    event TokensBurned(address indexed from, uint256 amount);
    event TokensBurnedFrom(address indexed from, uint256 amount, address indexed burner, string reason);
}