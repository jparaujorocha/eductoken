// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IEducLearning {
    function initialize(
        address _token,
        address _educator,
        address _student,
        address _course,
        address _config,
        address _pauseControl,
        address _multisig,
        address _proposal
    ) external;

    function completeCourse(
        address studentAddress, 
        string calldata courseId
    ) external;

    function issueReward(
        address studentAddress, 
        uint256 amount, 
        string calldata reason
    ) external;

    function batchIssueRewards(
        address[] calldata students, 
        uint256[] calldata amounts, 
        string[] calldata reasons
    ) external;

    function burnInactiveTokens(
        address studentAddress, 
        uint256 amount
    ) external;

    function setDailyMintingLimit(uint256 newLimit) external;

    function getDailyMintingRemaining() external view returns (uint256);

    function pause() external;
    function unpause() external;
}