const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("EducAccess", function () {
  let EducAccess;
  let access;
  let admin;
  let user1;
  let user2;
  
  // Role hashes
  let ADMIN_ROLE;
  let PAUSER_ROLE;
  let UPGRADER_ROLE;
  let EMERGENCY_ROLE;
  let DEFAULT_ADMIN_ROLE;

  beforeEach(async function () {
    // Get signers
    [admin, user1, user2] = await ethers.getSigners();
    
    // Calculate role hashes
    DEFAULT_ADMIN_ROLE = ethers.ZeroHash;
    ADMIN_ROLE = ethers.keccak256(ethers.toUtf8Bytes("ADMIN_ROLE"));
    PAUSER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("PAUSER_ROLE"));
    UPGRADER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("UPGRADER_ROLE"));
    EMERGENCY_ROLE = ethers.keccak256(ethers.toUtf8Bytes("EMERGENCY_ROLE"));
    
    // Deploy contract
    EducAccess = await ethers.getContractFactory("EducAccess");
    access = await EducAccess.deploy(admin.address);
  });

  describe("Deployment", function () {
    it("Should set the right admin", async function () {
      expect(await access.hasRole(ADMIN_ROLE, admin.address)).to.equal(true);
    });
    
    it("Should set all required roles for admin", async function () {
      expect(await access.hasRole(DEFAULT_ADMIN_ROLE, admin.address)).to.equal(true);
      expect(await access.hasRole(ADMIN_ROLE, admin.address)).to.equal(true);
      expect(await access.hasRole(PAUSER_ROLE, admin.address)).to.equal(true);
      expect(await access.hasRole(UPGRADER_ROLE, admin.address)).to.equal(true);
      expect(await access.hasRole(EMERGENCY_ROLE, admin.address)).to.equal(true);
    });
    
    it("Should revert when deployed with zero address as admin", async function () {
      await expect(
        EducAccess.deploy(ethers.ZeroAddress)
      ).to.be.revertedWith("EducAccess: admin cannot be zero address");
    });
    
    it("Should initialize as unpaused", async function () {
      expect(await access.paused()).to.equal(false);
    });
  });
  
  describe("Role Management", function () {
    it("Should allow admin to grant roles", async function () {
      await access.connect(admin).grantRole(PAUSER_ROLE, user1.address);
      expect(await access.hasRole(PAUSER_ROLE, user1.address)).to.equal(true);
    });
    
    it("Should allow admin to revoke roles", async function () {
      // First grant a role
      await access.connect(admin).grantRole(PAUSER_ROLE, user1.address);
      expect(await access.hasRole(PAUSER_ROLE, user1.address)).to.equal(true);
      
      // Then revoke it
      await access.connect(admin).revokeRole(PAUSER_ROLE, user1.address);
      expect(await access.hasRole(PAUSER_ROLE, user1.address)).to.equal(false);
    });
    
    it("Should emit RoleGranted event when granting a role", async function () {
      await expect(access.connect(admin).grantRole(PAUSER_ROLE, user1.address))
        .to.emit(access, "RoleGranted")
        .withArgs(PAUSER_ROLE, user1.address, admin.address);
    });
    
    it("Should emit RoleRevoked event when revoking a role", async function () {
      // First grant a role
      await access.connect(admin).grantRole(PAUSER_ROLE, user1.address);
      
      // Then check the revoke event
      await expect(access.connect(admin).revokeRole(PAUSER_ROLE, user1.address))
        .to.emit(access, "RoleRevoked")
        .withArgs(PAUSER_ROLE, user1.address, admin.address);
    });
    
    it("Should not allow non-admins to grant roles", async function () {
      await expect(
        access.connect(user1).grantRole(PAUSER_ROLE, user2.address)
      ).to.be.revertedWithCustomError(access, "AccessControlUnauthorizedAccount");
    });
    
    it("Should not allow non-admins to revoke roles", async function () {
      // First grant a role as admin
      await access.connect(admin).grantRole(PAUSER_ROLE, user1.address);
      
      // Try to revoke as non-admin
      await expect(
        access.connect(user2).revokeRole(PAUSER_ROLE, user1.address)
      ).to.be.revertedWithCustomError(access, "AccessControlUnauthorizedAccount");
    });
    
    it("Should get the admin role for a role", async function () {
      // The admin of all roles should be DEFAULT_ADMIN_ROLE by default
      expect(await access.getRoleAdmin(ADMIN_ROLE)).to.equal(DEFAULT_ADMIN_ROLE);
      expect(await access.getRoleAdmin(PAUSER_ROLE)).to.equal(DEFAULT_ADMIN_ROLE);
      expect(await access.getRoleAdmin(UPGRADER_ROLE)).to.equal(DEFAULT_ADMIN_ROLE);
      expect(await access.getRoleAdmin(EMERGENCY_ROLE)).to.equal(DEFAULT_ADMIN_ROLE);
    });
  });
  
  describe("Pause Functionality", function () {
    it("Should allow pauser to pause", async function () {
      await access.connect(admin).pause();
      expect(await access.paused()).to.equal(true);
    });
    
    it("Should allow pauser to unpause", async function () {
      // First pause
      await access.connect(admin).pause();
      expect(await access.paused()).to.equal(true);
      
      // Then unpause
      await access.connect(admin).unpause();
      expect(await access.paused()).to.equal(false);
    });
    
    it("Should not allow non-pauser to pause", async function () {
      await expect(
        access.connect(user1).pause()
      ).to.be.revertedWithCustomError(access, "AccessControlUnauthorizedAccount");
    });
    
    it("Should not allow non-pauser to unpause", async function () {
      // First pause as admin
      await access.connect(admin).pause();
      
      // Try to unpause as non-pauser
      await expect(
        access.connect(user1).unpause()
      ).to.be.revertedWithCustomError(access, "AccessControlUnauthorizedAccount");
    });
    
    it("Should emit Paused event when pausing", async function () {
      await expect(access.connect(admin).pause())
        .to.emit(access, "Paused")
        .withArgs(admin.address);
    });
    
    it("Should emit Unpaused event when unpausing", async function () {
      // First pause
      await access.connect(admin).pause();
      
      // Then check the unpause event
      await expect(access.connect(admin).unpause())
        .to.emit(access, "Unpaused")
        .withArgs(admin.address);
    });
    
    it("Should not allow pausing when already paused", async function () {
      // First pause
      await access.connect(admin).pause();
      
      // Try to pause again
      await expect(
        access.connect(admin).pause()
      ).to.be.revertedWithCustomError(access, "EnforcedPause");
    });
    
    it("Should not allow unpausing when already unpaused", async function () {
      // Try to unpause when not paused
      await expect(
        access.connect(admin).unpause()
      ).to.be.revertedWithCustomError(access, "ExpectedPause");
    });
    
    it("Should allow user with granted pauser role to pause", async function () {
      // Grant pauser role to user1
      await access.connect(admin).grantRole(PAUSER_ROLE, user1.address);
      
      // Pause as user1
      await access.connect(user1).pause();
      expect(await access.paused()).to.equal(true);
    });
  });
});