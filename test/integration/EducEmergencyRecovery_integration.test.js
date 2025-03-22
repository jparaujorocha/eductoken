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

    // Explicitly increase daily mint limit
    // First mint a small amount which should succeed
    await token.connect(admin).mint(admin.address, ethers.parseEther("1"));
    
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

    // Small mint to stay under limits
    await token.connect(admin).mint(systemContract.address, ethers.parseEther("100"));
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
      expect(emergencyAction.isActive).to.be.true;
      expect(emergencyAction.level).to.equal(2);
      expect(emergencyAction.reason).to.equal("System critical condition detected");
    });

    it("Should manage emergency levels with proper restrictions", async function () {
      // Declare Level 2 emergency
      await recoveryContract.connect(emergencyRole).declareEmergency(
        2, // Level 2 emergency
        "System performance degradation"
      );

      // De-escalate to level 1
      await recoveryContract.connect(emergencyRole).setEmergencyLevel(1);
      
      // Get current emergency level
      const currentLevel = await recoveryContract.currentEmergencyLevel();
      expect(currentLevel).to.equal(1);
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

      // Declare emergency first so we can test approval
      await recoveryContract.connect(emergencyRole).declareEmergency(
        2,
        "Valid emergency declaration"
      );

      await expect(
        recoveryContract.connect(user1).approveEmergencyAction(1)
      ).to.be.reverted;
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
      
      // Verify config was updated by checking treasury address
      const config = await recoveryContract.config();
      expect(config.treasury).to.equal(newTreasury);
    });
  });
});