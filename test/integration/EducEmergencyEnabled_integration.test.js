const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("EducEmergencyEnabled Integration Tests", function () {
  let tokenWithRecovery;
  let admin;
  let treasury;
  let emergencyRecovery;
  let user;

  beforeEach(async function () {
    [admin, treasury, emergencyRecovery, user] = await ethers.getSigners();

    // Deploy EducTokenWithRecovery which inherits from EducEmergencyEnabled
    const TokenFactory = await ethers.getContractFactory("EducTokenWithRecovery");
    tokenWithRecovery = await TokenFactory.deploy(
      admin.address,
      treasury.address,
      emergencyRecovery.address
    );
    
    // Grant emergency role
    await tokenWithRecovery.connect(admin).grantRole(
      ethers.keccak256(ethers.toUtf8Bytes("EMERGENCY_ROLE")), 
      emergencyRecovery.address
    );

    // Mint some tokens to the contract itself to test recovery
    await tokenWithRecovery.connect(admin).mint(tokenWithRecovery.target, ethers.parseEther("100"));
  });

  describe("Emergency Token Withdrawal", function () {
    it("Should allow emergency withdrawal of tokens by emergency recovery", async function () {
      // Arrange: Check initial balances
      const initialTreasuryBalance = await tokenWithRecovery.balanceOf(treasury.address);
      const initialContractBalance = await tokenWithRecovery.balanceOf(tokenWithRecovery.target);

      // Act: Execute emergency withdrawal through the recovery contract
      await tokenWithRecovery.connect(emergencyRecovery).executeEmergencyWithdrawal(
        tokenWithRecovery.target, 
        ethers.parseEther("50")
      );

      // Assert: Verify tokens were transferred to treasury
      const finalTreasuryBalance = await tokenWithRecovery.balanceOf(treasury.address);
      const finalContractBalance = await tokenWithRecovery.balanceOf(tokenWithRecovery.target);
      
      expect(finalTreasuryBalance).to.equal(initialTreasuryBalance + ethers.parseEther("50"));
      expect(finalContractBalance).to.equal(initialContractBalance - ethers.parseEther("50"));
    });

    it("Should prevent unauthorized withdrawal attempts", async function () {
      // Attempt unauthorized withdrawal
      await expect(
        tokenWithRecovery.connect(user).executeEmergencyWithdrawal(
          tokenWithRecovery.target, 
          ethers.parseEther("10")
        )
      ).to.be.revertedWith("EducEmergencyEnabled: caller is not recovery contract");
    });
  });
});