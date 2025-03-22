const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("EducAccess Integration Tests", function () {
  let accessContract;
  let admin;
  let roleManager;
  let pauserRole;
  let emergencyRole;
  let user1;
  let user2;

  const ADMIN_ROLE = ethers.keccak256(ethers.toUtf8Bytes("ADMIN_ROLE"));
  const PAUSER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("PAUSER_ROLE"));
  const UPGRADER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("UPGRADER_ROLE"));
  const EMERGENCY_ROLE = ethers.keccak256(ethers.toUtf8Bytes("EMERGENCY_ROLE"));

  beforeEach(async function () {
    [admin, roleManager, pauserRole, _, emergencyRole, user1, user2] = await ethers.getSigners();

    const AccessFactory = await ethers.getContractFactory("EducAccess");
    accessContract = await AccessFactory.deploy(admin.address);
  });

  describe("Role Management Workflow", function () {
    it("Should allow admin to grant and revoke roles", async function () {
      // Grant pauser role to roleManager
      await accessContract.connect(admin).grantRole(PAUSER_ROLE, roleManager.address);
      expect(await accessContract.hasRole(PAUSER_ROLE, roleManager.address)).to.be.true;

      // Revoke pauser role
      await accessContract.connect(admin).revokeRole(PAUSER_ROLE, roleManager.address);
      expect(await accessContract.hasRole(PAUSER_ROLE, roleManager.address)).to.be.false;
    });

    it("Should prevent unauthorized role management", async function () {
      await expect(
        accessContract.connect(user1).grantRole(ADMIN_ROLE, user2.address)
      ).to.be.reverted;

      await expect(
        accessContract.connect(user1).revokeRole(PAUSER_ROLE, admin.address)
      ).to.be.reverted;
    });

    it("Should support multiple role assignments", async function () {
      // Assign multiple roles to roleManager
      await accessContract.connect(admin).grantRole(PAUSER_ROLE, roleManager.address);
      await accessContract.connect(admin).grantRole(UPGRADER_ROLE, roleManager.address);

      expect(await accessContract.hasRole(PAUSER_ROLE, roleManager.address)).to.be.true;
      expect(await accessContract.hasRole(UPGRADER_ROLE, roleManager.address)).to.be.true;
    });
  });

  describe("Pause Mechanism Integration", function () {
    it("Should allow pausing and unpausing by authorized roles", async function () {
      // Grant pauser role
      await accessContract.connect(admin).grantRole(PAUSER_ROLE, pauserRole.address);

      // Pause by pauser
      await accessContract.connect(pauserRole).pause();
      expect(await accessContract.paused()).to.be.true;

      // Unpause by pauser
      await accessContract.connect(pauserRole).unpause();
      expect(await accessContract.paused()).to.be.false;
    });

    it("Should prevent pausing by unauthorized accounts", async function () {
      await expect(
        accessContract.connect(user1).pause()
      ).to.be.reverted;

      await expect(
        accessContract.connect(user1).unpause()
      ).to.be.reverted;
    });
  });

  describe("Complex Role Interaction", function () {
    it("Should maintain role hierarchy and permissions", async function () {
      // Grant multiple roles
      await accessContract.connect(admin).grantRole(EMERGENCY_ROLE, emergencyRole.address);
      await accessContract.connect(admin).grantRole(UPGRADER_ROLE, emergencyRole.address);

      // Verify multiple role assignments
      expect(await accessContract.hasRole(EMERGENCY_ROLE, emergencyRole.address)).to.be.true;
      expect(await accessContract.hasRole(UPGRADER_ROLE, emergencyRole.address)).to.be.true;
    });

    it("Should prevent role conflicts", async function () {
        // Grant pauser role
        await accessContract.connect(admin).grantRole(PAUSER_ROLE, roleManager.address);
      
        // Specifically check that granting ADMIN_ROLE fails with the correct error
        await expect(
          accessContract.connect(admin).grantRole(ADMIN_ROLE, roleManager.address)
        ).to.be.revertedWithCustomError(accessContract, "AccessControlConflictingRole");
      });
  });

  describe("Emergency Role Special Handling", function () {
    it("Should support emergency role actions", async function () {
      // Grant emergency role
      await accessContract.connect(admin).grantRole(EMERGENCY_ROLE, emergencyRole.address);

      // Verify emergency role capabilities
      expect(await accessContract.hasRole(EMERGENCY_ROLE, emergencyRole.address)).to.be.true;
    });
  });
});