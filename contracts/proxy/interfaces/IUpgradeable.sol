// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IUpgradeable
 * @dev Interface that reflects all public/external methods from EducTokenUpgradeable contract
 */
interface IUpgradeable {
    function pause() external;
    function unpause() external;
    function setStudentContract(address _studentContract) external;

    function mint(address to, uint256 amount) external;
    function mintReward(address student, uint256 amount, string calldata reason) external;
    function batchMintReward(
        address[] calldata students,
        uint256[] calldata amounts,
        string[] calldata reasons
    ) external;

    function burn(uint256 amount) external;
    function burnFromInactive(address from, uint256 amount, string calldata reason) external;

    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    function isAccountInactive(address account) external view returns (bool);
    function getDailyMintingRemaining() external view returns (uint256);
}
