const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("EducEmergencyEnabled Integration Tests", function () {
  let emergencyEnabledContract;
  let token;
  let admin;
  let treasury;
  let emergencyRecovery;
  let attacker;

  beforeEach(async function () {
    [admin, treasury, emergencyRecovery, attacker] = await ethers.getSigners();

    // Deploy Token for testing
    const TokenFactory = await ethers.getContractFactory("EducToken");
    token = await TokenFactory.deploy(admin.address);

    // Deploy Emergency Enabled Contract
    const EmergencyEnabledFactory = await ethers.getContractFactory("ConcreteEmergencyEnabled");
    emergencyEnabledContract = await EmergencyEnabledFactory.deploy(
      treasury.address, 
      emergencyRecovery.address
    );

    // Mint tokens to the emergency enabled contract
    await token.connect(admin).mint(emergencyEnabledContract.target, ethers.parseEther("10000"));

    // Send ETH to the contract
    await admin.sendTransaction({
      to: emergencyEnabledContract.target,
      value: ethers.parseEther("5")
    });
  });

  describe("Emergency Token Withdrawal", function () {
    it("Should allow emergency withdrawal of tokens", async function () {
      const withdrawalAmount = ethers.parseEther("5000");
      const initialContractBalance = await token.balanceOf(emergencyEnabledContract.target);
      const initialTreasuryBalance = await token.balanceOf(treasury.address);

      // Perform emergency withdrawal
      await emergencyEnabledContract.connect(emergencyRecovery).executeEmergencyWithdrawal(
        token.target, 
        withdrawalAmount
      );

      // Verify balances
      const finalContractBalance = await token.balanceOf(emergencyEnabledContract.target);
      const finalTreasuryBalance = await token.balanceOf(treasury.address);

      expect(finalContractBalance).to.equal(initialContractBalance - withdrawalAmount);
      expect(finalTreasuryBalance).to.equal(initialTreasuryBalance + withdrawalAmount);
    });

    it("Should limit token withdrawal to contract's balance", async function () {
      const excessiveWithdrawalAmount = ethers.parseEther("15000");
      const initialTreasuryBalance = await token.balanceOf(treasury.address);

      // Attempt to withdraw more than contract's balance
      await emergencyEnabledContract.connect(emergencyRecovery).executeEmergencyWithdrawal(
        token.target, 
        excessiveWithdrawalAmount
      );

      // Verify entire balance was withdrawn
      const finalContractBalance = await token.balanceOf(emergencyEnabledContract.target);
      const finalTreasuryBalance = await token.balanceOf(treasury.address);

      expect(finalContractBalance).to.equal(0);
      expect(finalTreasuryBalance).to.equal(initialTreasuryBalance + ethers.parseEther("10000"));
    });
  });

  describe("Emergency ETH Withdrawal", function () {
    it("Should allow emergency ETH withdrawal", async function () {
      const withdrawalAmount = ethers.parseEther("3");
      const initialContractBalance = await ethers.provider.getBalance(emergencyEnabledContract.target);
      const initialTreasuryBalance = await ethers.provider.getBalance(treasury.address);

      // Perform emergency ETH withdrawal
      await emergencyEnabledContract.connect(emergencyRecovery).executeEmergencyETHWithdrawal(
        withdrawalAmount
      );

      // Verify ETH balances
      const finalContractBalance = await ethers.provider.getBalance(emergencyEnabledContract.target);
      const finalTreasuryBalance = await ethers.provider.getBalance(treasury.address);

      expect(finalContractBalance).to.equal(initialContractBalance - withdrawalAmount);
      expect(finalTreasuryBalance).to.be.closeTo(
        initialTreasuryBalance + withdrawalAmount, 
        ethers.parseEther("0.1") // Allow for gas costs
      );
    });

    it("Should limit ETH withdrawal to contract's balance", async function () {
      const excessiveWithdrawalAmount = ethers.parseEther("10");
      const initialTreasuryBalance = await ethers.provider.getBalance(treasury.address);

      // Attempt to withdraw more than contract's balance
      await emergencyEnabledContract.connect(emergencyRecovery).executeEmergencyETHWithdrawal(
        excessiveWithdrawalAmount
      );

      // Verify entire ETH balance was withdrawn
      const finalContractBalance = await ethers.provider.getBalance(emergencyEnabledContract.target);
      const finalTreasuryBalance = await ethers.provider.getBalance(treasury.address);

      expect(finalContractBalance).to.equal(0);
      expect(finalTreasuryBalance).to.be.closeTo(
        initialTreasuryBalance + ethers.parseEther("5"), 
        ethers.parseEther("0.1") // Allow for gas costs
      );
    });
  });

  describe("Access Control", function () {
    it("Should prevent unauthorized emergency withdrawal", async function () {
      await expect(
        emergencyEnabledContract.connect(attacker).executeEmergencyWithdrawal(
          token.target, 
          ethers.parseEther("1000")
        )
      ).to.be.revertedWith("EducEmergencyEnabled: caller is not recovery contract");

      await expect(
        emergencyEnabledContract.connect(attacker).executeEmergencyETHWithdrawal(
          ethers.parseEther("1")
        )
      ).to.be.revertedWith("EducEmergencyEnabled: caller is not recovery contract");
    });
  });
});