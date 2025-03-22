const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("EducPause", function () {
  let EducPause;
  let pause;
  let admin;
  let emergencyRole;
  let user1;
  let user2;
  
  // Constants for roles
  let ADMIN_ROLE;
  let EMERGENCY_ROLE;
  
  // Constants for pause flags (from SystemConstants)
  const PAUSE_FLAG_MINT = 1 << 0;     // 1
  const PAUSE_FLAG_TRANSFER = 1 << 1; // 2
  const PAUSE_FLAG_BURN = 1 << 2;     // 4
  const PAUSE_FLAG_REGISTER = 1 << 3; // 8
  const PAUSE_FLAG_ALL = 0xFFFFFFFF;  // All flags
  
  // Event signatures
  const EVENT_SYSTEM_PAUSED = "SystemPaused";
  const EVENT_SYSTEM_UNPAUSED = "SystemUnpaused";
  const EVENT_GRANULAR_PAUSE_UPDATED = "GranularPauseUpdated";
  const EVENT_PAUSE_OVERRIDE_SET = "PauseOverrideSet";

  beforeEach(async function () {
    // Get signers
    [admin, emergencyRole, user1, user2] = await ethers.getSigners();
    
    // Calculate role hashes
    ADMIN_ROLE = ethers.keccak256(ethers.toUtf8Bytes("ADMIN_ROLE"));
    EMERGENCY_ROLE = ethers.keccak256(ethers.toUtf8Bytes("EMERGENCY_ROLE"));
    
    // Deploy pause contract
    EducPause = await ethers.getContractFactory("EducPause");
    pause = await EducPause.deploy(admin.address);
    
    // Grant emergency role to emergencyRole account
    await pause.grantRole(EMERGENCY_ROLE, emergencyRole.address);
  });

  describe("Deployment", function () {
    it("Should set the right admin", async function () {
      expect(await pause.hasRole(ADMIN_ROLE, admin.address)).to.equal(true);
    });
    
    it("Should set admin as emergency role", async function () {
      expect(await pause.hasRole(EMERGENCY_ROLE, admin.address)).to.equal(true);
    });
    
    it("Should initialize with no paused functions", async function () {
      expect(await pause.getCurrentPauseFlags()).to.equal(0);
    });
    
    it("Should initialize in unpaused state", async function () {
      expect(await pause.isPaused()).to.equal(false);
    });
  });

  describe("Emergency Pause", function () {
    it("Should allow emergency role to set emergency pause", async function () {
      await pause.connect(emergencyRole).setEmergencyPause(true);
      
      expect(await pause.isPaused()).to.equal(true);
      expect(await pause.getCurrentPauseFlags()).to.equal(PAUSE_FLAG_ALL);
    });
    
    it("Should emit SystemPaused event when setting emergency pause", async function () {
      await expect(pause.connect(emergencyRole).setEmergencyPause(true))
        .to.emit(pause, EVENT_SYSTEM_PAUSED);
    });
    
    it("Should allow emergency role to clear emergency pause", async function () {
      // First set pause
      await pause.connect(emergencyRole).setEmergencyPause(true);
      
      // Then clear it
      await pause.connect(emergencyRole).setEmergencyPause(false);
      
      expect(await pause.isPaused()).to.equal(false);
      expect(await pause.getCurrentPauseFlags()).to.equal(0);
    });
    
    it("Should emit SystemUnpaused event when clearing emergency pause", async function () {
      // First set pause
      await pause.connect(emergencyRole).setEmergencyPause(true);
      
      // Then clear it
      await expect(pause.connect(emergencyRole).setEmergencyPause(false))
        .to.emit(pause, EVENT_SYSTEM_UNPAUSED);
    });
    
    it("Should track the last pause authority", async function () {
      await pause.connect(emergencyRole).setEmergencyPause(true);
      
      expect(await pause.getLastPauseAuthority()).to.equal(emergencyRole.address);
    });
    
    it("Should not allow non-emergency role to set emergency pause", async function () {
      await expect(
        pause.connect(user1).setEmergencyPause(true)
      ).to.be.revertedWith("EducPause: caller does not have emergency role");
    });
  });

  describe("Granular Pause", function () {
    it("Should allow emergency role to set granular pause", async function () {
      // Pause minting and transfers
      const flags = PAUSE_FLAG_MINT | PAUSE_FLAG_TRANSFER;
            
      await pause.connect(emergencyRole).setGranularPauseLegacy(flags, true);
      
      expect(await pause.isPaused()).to.equal(true);
      expect(await pause.getCurrentPauseFlags()).to.equal(flags);
    });
    
    it("Should emit GranularPauseUpdated event when setting granular pause", async function () {
      const flags = PAUSE_FLAG_MINT | PAUSE_FLAG_TRANSFER;
      
      
      await expect(pause.connect(emergencyRole).setGranularPauseLegacy(flags, true))
        .to.emit(pause, EVENT_GRANULAR_PAUSE_UPDATED);
    });
    
    it("Should allow emergency role to clear granular pause", async function () {
      // First set pause
      const flags = PAUSE_FLAG_MINT | PAUSE_FLAG_TRANSFER;
      
      await pause.connect(emergencyRole).setGranularPauseLegacy(flags, true);
      
      // Then clear just the minting pause
      
      await pause.connect(emergencyRole).setGranularPauseLegacy(PAUSE_FLAG_MINT, false);
      
      expect(await pause.getCurrentPauseFlags()).to.equal(PAUSE_FLAG_TRANSFER);
    });
    
    it("Should allow setting multiple granular pauses", async function () {
      // Set first pause
      
      await pause.connect(emergencyRole).setGranularPauseLegacy(PAUSE_FLAG_MINT, true);
      
      // Set second pause
      
      await pause.connect(emergencyRole).setGranularPauseLegacy(PAUSE_FLAG_TRANSFER, true);
      
      expect(await pause.getCurrentPauseFlags()).to.equal(PAUSE_FLAG_MINT | PAUSE_FLAG_TRANSFER);
    });
    
    it("Should allow clearing all granular pauses at once", async function () {
      // Set multiple pauses
      const flags = PAUSE_FLAG_MINT | PAUSE_FLAG_TRANSFER | PAUSE_FLAG_BURN;
      
      await pause.connect(emergencyRole).setGranularPauseLegacy(flags, true);
      
      // Clear all at once
      
      await pause.connect(emergencyRole).setGranularPauseLegacy(flags, false);
      
      expect(await pause.getCurrentPauseFlags()).to.equal(0);
      expect(await pause.isPaused()).to.equal(false);
    });
    
    it("Should unpause system when no flags remain", async function () {
      // Set a pause
      
      await pause.connect(emergencyRole).setGranularPauseLegacy(PAUSE_FLAG_MINT, true);
      
      expect(await pause.isPaused()).to.equal(true);
      
      // Clear the pause
      
      await pause.connect(emergencyRole).setGranularPauseLegacy(PAUSE_FLAG_MINT, false);
      
      expect(await pause.isPaused()).to.equal(false);
    });
    
    it("Should not allow non-emergency role to set granular pause", async function () {
      await expect(
        
        pause.connect(user1).setGranularPauseLegacy(PAUSE_FLAG_MINT, true)
      ).to.be.revertedWith("EducPause: caller does not have emergency role");
    });
    
    it("Should support granular pause with structured parameters", async function () {
      // Using the structured params version
      const params = {
        functionFlags: PAUSE_FLAG_MINT | PAUSE_FLAG_TRANSFER,
        isPaused: true
      };
      
      // Aqui estamos usando a versão com struct, então mantemos como está
      await pause.connect(emergencyRole)["setGranularPause((uint32,bool))"](params);
      
      expect(await pause.getCurrentPauseFlags()).to.equal(params.functionFlags);
    });
  });

  describe("Function Pause Checking", function () {
    beforeEach(async function () {
      // Set some paused functions
      
      await pause.connect(emergencyRole).setGranularPauseLegacy(PAUSE_FLAG_MINT | PAUSE_FLAG_TRANSFER, true);
    });
    
    it("Should correctly report paused functions", async function () {
      expect(await pause.isFunctionPaused(PAUSE_FLAG_MINT)).to.equal(true);
      expect(await pause.isFunctionPaused(PAUSE_FLAG_TRANSFER)).to.equal(true);
      expect(await pause.isFunctionPaused(PAUSE_FLAG_BURN)).to.equal(false);
    });
    
    it("Should correctly report unpaused functions", async function () {
      expect(await pause.isFunctionPaused(PAUSE_FLAG_BURN)).to.equal(false);
      expect(await pause.isFunctionPaused(PAUSE_FLAG_REGISTER)).to.equal(false);
    });
    
    it("Should correctly report paused functions by address", async function () {
      expect(await pause.isFunctionPausedForAddress(user1.address, PAUSE_FLAG_MINT)).to.equal(true);
      expect(await pause.isFunctionPausedForAddress(user1.address, PAUSE_FLAG_TRANSFER)).to.equal(true);
      expect(await pause.isFunctionPausedForAddress(user1.address, PAUSE_FLAG_BURN)).to.equal(false);
    });
  });

  describe("Pause Overrides", function () {
    beforeEach(async function () {
      // Set some paused functions
      
      await pause.connect(emergencyRole).setGranularPauseLegacy(PAUSE_FLAG_MINT | PAUSE_FLAG_TRANSFER, true);
    });
    
    it("Should allow admin to set pause override for address", async function () {
      await pause.connect(admin).setPauseOverride(user1.address, PAUSE_FLAG_MINT, true);
      
      // Function should appear unpaused for user1 due to override
      expect(await pause.isFunctionPausedForAddress(user1.address, PAUSE_FLAG_MINT)).to.equal(false);
      
      // But it should still be paused globally
      expect(await pause.isFunctionPaused(PAUSE_FLAG_MINT)).to.equal(true);
      
      // And paused for other users
      expect(await pause.isFunctionPausedForAddress(user2.address, PAUSE_FLAG_MINT)).to.equal(true);
    });
    
    it("Should emit PauseOverrideSet event when setting override", async function () {
      await expect(pause.connect(admin).setPauseOverride(user1.address, PAUSE_FLAG_MINT, true))
        .to.emit(pause, EVENT_PAUSE_OVERRIDE_SET);
    });
    
    it("Should allow admin to clear pause override", async function () {
      // First set override
      await pause.connect(admin).setPauseOverride(user1.address, PAUSE_FLAG_MINT, true);
      
      // Then clear it
      await pause.connect(admin).setPauseOverride(user1.address, PAUSE_FLAG_MINT, false);
      
      // Function should appear paused again for user1
      expect(await pause.isFunctionPausedForAddress(user1.address, PAUSE_FLAG_MINT)).to.equal(true);
    });
    
    it("Should not allow setting override for zero address", async function () {
      await expect(
        pause.connect(admin).setPauseOverride(ethers.ZeroAddress, PAUSE_FLAG_MINT, true)
      ).to.be.revertedWith("EducPause: Cannot override zero address");
    });
    
    it("Should not allow non-admin to set pause override", async function () {
      await expect(
        pause.connect(user1).setPauseOverride(user1.address, PAUSE_FLAG_MINT, true)
      ).to.be.revertedWith("EducPause: caller does not have admin role");
    });
  });

  describe("Pause History", function () {
    it("Should track pause actions history", async function () {
      // Set a pause
      
      await pause.connect(emergencyRole).setGranularPauseLegacy(PAUSE_FLAG_MINT, true);
      
      // Get pause action count
      const pauseActionCount = await pause.getPauseActionCount();
      expect(pauseActionCount).to.equal(1);
      
      // Check pause action details
      const pauseAction = await pause.getPauseAction(0);
      expect(pauseAction.authority).to.equal(emergencyRole.address);
      expect(pauseAction.flags).to.equal(PAUSE_FLAG_MINT);
      expect(pauseAction.isGlobal).to.equal(false);
      // timestamp is also recorded
    });
    
    it("Should track unpause actions history", async function () {
      // Set a pause
      
      await pause.connect(emergencyRole).setGranularPauseLegacy(PAUSE_FLAG_MINT, true);
      
      // Clear the pause
      
      await pause.connect(emergencyRole).setGranularPauseLegacy(PAUSE_FLAG_MINT, false);
      
      // Get unpause action count
      const unpauseActionCount = await pause.getUnpauseActionCount();
      expect(unpauseActionCount).to.equal(1);
      
      // Check unpause action details
      const unpauseAction = await pause.getUnpauseAction(0);
      expect(unpauseAction.authority).to.equal(emergencyRole.address);
      expect(unpauseAction.unsetFlags).to.equal(PAUSE_FLAG_MINT);
      expect(unpauseAction.isGlobal).to.equal(false);
      // timestamp is also recorded
    });
  });
});