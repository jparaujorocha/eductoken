const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("EducRoles Integration Tests", function () {
  let accessContract;
  let admin;

  // Role constants
  const ADMIN_ROLE = ethers.keccak256(ethers.toUtf8Bytes("ADMIN_ROLE"));
  const EDUCATOR_ROLE = ethers.keccak256(ethers.toUtf8Bytes("EDUCATOR_ROLE"));
  const MINTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE"));
  const PAUSER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("PAUSER_ROLE"));
  const UPGRADER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("UPGRADER_ROLE"));
  const EMERGENCY_ROLE = ethers.keccak256(ethers.toUtf8Bytes("EMERGENCY_ROLE"));

  beforeEach(async function () {
    [admin, user] = await ethers.getSigners();

    // Use EducAccess which incorporates EducRoles
    const AccessFactory = await ethers.getContractFactory("EducAccess");
    accessContract = await AccessFactory.deploy(admin.address);
  });

  describe("Role Validation and Management", function () {
    it("Should have all predefined roles set up correctly", async function () {
        // Verify admin has all the predefined roles
        expect(await accessContract.hasRole(ADMIN_ROLE, admin.address)).to.be.true;
        expect(await accessContract.hasRole(PAUSER_ROLE, admin.address)).to.be.true;
        expect(await accessContract.hasRole(UPGRADER_ROLE, admin.address)).to.be.true;
        expect(await accessContract.hasRole(EMERGENCY_ROLE, admin.address)).to.be.true;
    });

    it("Should handle roles correctly when granted and revoked", async function () {
      const [_, user] = await ethers.getSigners();
      
      // Grant educator role
      await accessContract.connect(admin).grantRole(EDUCATOR_ROLE, user.address);
      expect(await accessContract.hasRole(EDUCATOR_ROLE, user.address)).to.be.true;
      
      // Revoke educator role
      await accessContract.connect(admin).revokeRole(EDUCATOR_ROLE, user.address);
      expect(await accessContract.hasRole(EDUCATOR_ROLE, user.address)).to.be.false;
    });

    it("Should prevent unauthorized roles management", async function () {
      const [_, unauthorizedUser, someUser] = await ethers.getSigners();
      
      // Unauthorized user tries to grant role
      await expect(
        accessContract.connect(unauthorizedUser).grantRole(EDUCATOR_ROLE, someUser.address)
      ).to.be.reverted;
    });
  });
});