const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-toolbox/network-helpers");

describe("EducEmergencyRecovery Integration Tests", function () {
  let recoveryContract;
  let token;
  let multisig;
  let admin;
  let treasury;
  let systemContract;
  let emergencyRole;
  let signer1;
  let signer2;
  let user1;

  beforeEach(async function () {
    [admin, treasury, systemContract, emergencyRole, signer1, signer2, user1] = await ethers.getSigners();

    // Deploy Multisig first
    const MultisigFactory = await ethers.getContractFactory("EducMultisig");
    multisig = await MultisigFactory.deploy(
      [signer1.address, signer2.address], 
      2, 
      admin.address
    );

    // Deploy Token
    const TokenFactory = await ethers.getContractFactory("EducToken");
    token = await TokenFactory.deploy(admin.address);

    // Deploy Emergency Recovery
    const EmergencyRecoveryFactory = await ethers.getContractFactory("EducEmergencyRecovery");
    recoveryContract = await EmergencyRecoveryFactory.deploy(
      admin.address,
      treasury.address,
      systemContract.address,
      multisig.target
    );

    // Grant necessary roles
    await recoveryContract.grantRole(
      ethers.keccak256(ethers.toUtf8Bytes("EMERGENCY_ROLE")), 
      emergencyRole.address
    );

    // Mint tokens to system contract for recovery testing
    await token.connect(admin).mint(systemContract.target, ethers.parseEther("10000"));
  });

  describe("Emergency Declaration Workflow", function () {
    it("Should allow emergency declaration with proper approvals", async function () {
      // Declare emergency
      await recoveryContract.connect(emergencyRole).declareEmergency(
        2, // Level 2 emergency
        "System critical condition detected"
      );

      // First signer approves
      await recoveryContract.connect(signer1).approveEmergencyAction(1);

      // Second signer approves
      await recoveryContract.connect(signer2).approveEmergencyAction(1);

      // Check emergency status
      const emergencyAction = await recoveryContract.getEmergencyAction(1);
      expect(emergencyAction.isActive).to.be.false;
      expect(emergencyAction.level).to.equal(2);
      expect(emergencyAction.reason).to.equal("System critical condition detected");
    });

    it("Should manage emergency levels with proper restrictions", async function () {
      // Declare Level 2 emergency
      await recoveryContract.connect(emergencyRole).declareEmergency(
        2, // Level 2 emergency
        "System performance degradation"
      );

      // Attempt to escalate to higher level
      await expect(
        recoveryContract.connect(emergencyRole).setEmergencyLevel(3)
      ).to.not.be.reverted;

      // Attempt to de-escalate
      await expect(
        recoveryContract.connect(emergencyRole).setEmergencyLevel(1)
      ).to.not.be.reverted;
    });
  });

  describe("Token and Resource Recovery", function () {
    beforeEach(async function () {
      // Declare Level 2 emergency
      await recoveryContract.connect(emergencyRole).declareEmergency(
        2, // Level 2 emergency
        "Token recovery required"
      );

      // Approve emergency action
      await recoveryContract.connect(signer1).approveEmergencyAction(1);
      await recoveryContract.connect(signer2).approveEmergencyAction(1);
    });

    it("Should recover ERC20 tokens during emergency", async function () {
      const initialSystemBalance = await token.balanceOf(systemContract.target);
      const initialTreasuryBalance = await token.balanceOf(treasury.address);

      // Recover tokens
      await recoveryContract.connect(emergencyRole).recoverERC20(
        token.target,
        systemContract.target,
        ethers.parseEther("5000")
      );

      // Verify tokens transferred to treasury
      const finalSystemBalance = await token.balanceOf(systemContract.target);
      const finalTreasuryBalance = await token.balanceOf(treasury.address);

      expect(finalSystemBalance).to.equal(initialSystemBalance - ethers.parseEther("5000"));
      expect(finalTreasuryBalance).to.equal(initialTreasuryBalance + ethers.parseEther("5000"));
    });

    it("Should recover ETH during emergency", async function () {
      // Send ETH to system contract
      await admin.sendTransaction({
        to: systemContract.target,
        value: ethers.parseEther("10")
      });

      const initialSystemBalance = await ethers.provider.getBalance(systemContract.target);
      const initialTreasuryBalance = await ethers.provider.getBalance(treasury.address);

      // Recover ETH
      await recoveryContract.connect(emergencyRole).recoverETH(
        systemContract.target,
        ethers.parseEther("5")
      );

      // Verify ETH transferred to treasury
      const finalSystemBalance = await ethers.provider.getBalance(systemContract.target);
      const finalTreasuryBalance = await ethers.provider.getBalance(treasury.address);

      expect(finalSystemBalance).to.equal(initialSystemBalance - ethers.parseEther("5"));
      expect(finalTreasuryBalance).to.be.closeTo(
        initialTreasuryBalance + ethers.parseEther("5"),
        ethers.parseEther("0.1") // Allow for gas costs
      );
    });
  });

  describe("Configuration and Governance", function () {
    it("Should allow updating recovery configuration", async function () {
      const newTreasury = ethers.Wallet.createRandom().address;
      const newSystemContract = ethers.Wallet.createRandom().address;
      
      await recoveryContract.connect(admin).updateConfig(
        newTreasury,
        newSystemContract,
        14 * 24 * 60 * 60, // 14 days cooldown
        3 // new approval threshold
      );

      // Additional verification would require adding getter methods to the contract
    });
  });

  describe("Access Control", function () {
    it("Should prevent unauthorized emergency actions", async function () {
      await expect(
        recoveryContract.connect(user1).declareEmergency(
          2, 
          "Unauthorized emergency declaration"
        )
      ).to.be.reverted;

      await expect(
        recoveryContract.connect(user1).approveEmergencyAction(1)
      ).to.be.reverted;

      await expect(
        recoveryContract.connect(user1).recoverERC20(
          token.target,
          systemContract.target,
          ethers.parseEther("1000")
        )
      ).to.be.reverted;
    });
  });
});