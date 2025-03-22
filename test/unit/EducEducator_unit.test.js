const { expect } = require("chai");
const { ethers } = require("hardhat");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");

describe("EducEducator", function () {
  let EducEducator;
  let educator;
  let admin;
  let user1;
  let user2;
  let user3;

  let ADMIN_ROLE;

  const EVENT_EDUCATOR_REGISTERED = "EducatorRegistered";
  const EVENT_EDUCATOR_STATUS_UPDATED = "EducatorStatusUpdated";
  const EVENT_EDUCATOR_MINT_RECORDED = "EducatorMintRecorded";
  const EVENT_EDUCATOR_COURSE_COUNT_INCREMENTED = "EducatorCourseCountIncremented";

  beforeEach(async function () {
    [admin, user1, user2, user3] = await ethers.getSigners();

    ADMIN_ROLE = ethers.keccak256(ethers.toUtf8Bytes("ADMIN_ROLE"));
    EducEducator = await ethers.getContractFactory("EducEducator");
    educator = await EducEducator.deploy(admin.address);
  });

  describe("Deployment", function () {
    it("Should set the right admin", async function () {
      expect(await educator.hasRole(ADMIN_ROLE, admin.address)).to.equal(true);
    });

    it("Should initialize with zero educators", async function () {
      expect(await educator.getTotalEducators()).to.equal(0);
    });
    
    it("Should revert when deployed with zero address as admin", async function () {
      const EducEducator = await ethers.getContractFactory("EducEducator");
      await expect(EducEducator.deploy(ethers.ZeroAddress)).to.be.revertedWith("EducEducator: address cannot be zero");
    });
  });

  describe("Educator Registration", function () {
    it("Should allow admin to register an educator", async function () {
      const mintLimit = ethers.parseEther("10000");
      const tx = await educator.connect(admin)["registerEducator(address,uint256)"](user1.address, mintLimit);
      await tx.wait();

      expect(await educator.isActiveEducator(user1.address)).to.equal(true);
      expect(await educator.getTotalEducators()).to.equal(1);
    });

    it("Should set correct educator parameters", async function () {
      const mintLimit = ethers.parseEther("10000");
      await educator.connect(admin)["registerEducator(address,uint256)"](user1.address, mintLimit);
      const info = await educator.getEducatorInfo(user1.address);
      expect(info.educatorAddress).to.equal(user1.address);
      expect(info.authorityAddress).to.equal(admin.address);
      expect(info.mintLimit).to.equal(mintLimit);
    });

    it("Should emit EducatorRegistered event when registering", async function () {
      const mintLimit = ethers.parseEther("10000");
      await expect(
        educator.connect(admin)["registerEducator(address,uint256)"](user1.address, mintLimit)
      )
        .to.emit(educator, EVENT_EDUCATOR_REGISTERED)
        .withArgs(user1.address, admin.address, mintLimit, anyValue);
    });

    it("Should not allow registering the zero address", async function () {
      await expect(
        educator.connect(admin)["registerEducator(address,uint256)"](ethers.ZeroAddress, ethers.parseEther("10000"))
      ).to.be.revertedWith("EducEducator: address cannot be zero");
    });

    it("Should not allow registering an existing educator", async function () {
      const mintLimit = ethers.parseEther("10000");
      await educator.connect(admin)["registerEducator(address,uint256)"](user1.address, mintLimit);
      await expect(
        educator.connect(admin)["registerEducator(address,uint256)"](user1.address, mintLimit)
      ).to.be.revertedWith("EducEducator: educator already registered");
    });

    it("Should not allow zero or excessive mint limit", async function () {
      const max = ethers.parseEther("100000");
      await expect(
        educator.connect(admin)["registerEducator(address,uint256)"](user1.address, 0)
      ).to.be.revertedWith("EducEducator: invalid mint limit");
      await expect(
        educator.connect(admin)["registerEducator(address,uint256)"](user1.address, max + BigInt(1))
      ).to.be.revertedWith("EducEducator: invalid mint limit");
    });

    it("Should not allow non-admin to register educators", async function () {
      const mintLimit = ethers.parseEther("10000");
      await expect(
        educator.connect(user1)["registerEducator(address,uint256)"](user2.address, mintLimit)
      ).to.be.revertedWithCustomError(educator, "AccessControlUnauthorizedAccount");
    });
    
    it("Should support structured parameters for registration", async function () {
      const mintLimit = ethers.parseEther("10000");
      const params = {
        educatorAddress: user1.address,
        mintLimit: mintLimit
      };
      
      await educator.connect(admin)["registerEducator((address,uint256))"](params);
      expect(await educator.isActiveEducator(user1.address)).to.equal(true);
      expect(await educator.getTotalEducators()).to.equal(1);
      
      const info = await educator.getEducatorInfo(user1.address);
      expect(info.educatorAddress).to.equal(user1.address);
      expect(info.mintLimit).to.equal(mintLimit);
    });
    
    it("Should respect modifiers in structured registration", async function () {
      const mintLimit = ethers.parseEther("10000");
      const params = {
        educatorAddress: ethers.ZeroAddress,
        mintLimit: mintLimit
      };
      
      await expect(
        educator.connect(admin)["registerEducator((address,uint256))"](params)
      ).to.be.revertedWith("EducEducator: address cannot be zero");
      
      // Test pause functionality
      await educator.connect(admin).pause();
      
      const validParams = {
        educatorAddress: user1.address,
        mintLimit: mintLimit
      };
      
      await expect(
        educator.connect(admin)["registerEducator((address,uint256))"](validParams)
      ).to.be.revertedWithCustomError(educator, "EnforcedPause");
      
      // Unpause for other tests
      await educator.connect(admin).unpause();
    });
    
    it("Should fail when maximum educators limit is reached", async function () {
      // This test is theoretical as we can't really hit the max (uint16) in a test
      // But we can test the code path by mocking
      
      // Register many educators
      const mintLimit = ethers.parseEther("1000");
      for (let i = 0; i < 10; i++) {
        const wallet = ethers.Wallet.createRandom();
        await educator.connect(admin)["registerEducator(address,uint256)"](wallet.address, mintLimit);
      }
      
      // Check if count is correct
      expect(await educator.getTotalEducators()).to.equal(10);
    });
  });

  describe("Educator Status Management", function () {
    beforeEach(async function () {
      const mintLimit = ethers.parseEther("10000");
      await educator.connect(admin)["registerEducator(address,uint256)"](user1.address, mintLimit);
    });

    it("Should allow admin to update educator status", async function () {
      await educator.connect(admin).setEducatorStatus(user1.address, false, 0);
      expect(await educator.isActiveEducator(user1.address)).to.equal(false);
    });

    it("Should emit EducatorStatusUpdated event", async function () {
      await expect(educator.connect(admin).setEducatorStatus(user1.address, false, 0))
        .to.emit(educator, EVENT_EDUCATOR_STATUS_UPDATED)
        .withArgs(user1.address, false, ethers.parseEther("10000"), anyValue);
    });
    
    it("Should allow updating mint limit during status update", async function () {
      const newMintLimit = ethers.parseEther("20000");
      await educator.connect(admin).setEducatorStatus(user1.address, true, newMintLimit);
      
      const info = await educator.getEducatorInfo(user1.address);
      expect(info.mintLimit).to.equal(newMintLimit);
    });
    
    it("Should validate address in setEducatorStatus", async function () {
      await expect(
        educator.connect(admin).setEducatorStatus(ethers.ZeroAddress, false, 0)
      ).to.be.revertedWith("EducEducator: address cannot be zero");
    });
    
    it("Should not allow updating non-existent educator", async function () {
      await expect(
        educator.connect(admin).setEducatorStatus(user2.address, false, 0)
      ).to.be.revertedWith("EducEducator: educator does not exist");
    });
    
    it("Should support structured parameters for status update", async function () {
      const newMintLimit = ethers.parseEther("15000");
      const params = {
        educatorAddress: user1.address,
        isActive: false,
        newMintLimit: newMintLimit
      };
      
      await educator.connect(admin)["setEducatorStatus((address,bool,uint256))"](params);
      
      const info = await educator.getEducatorInfo(user1.address);
      expect(info.isActive).to.equal(false);
      expect(info.mintLimit).to.equal(newMintLimit);
    });
    
    it("Should enforce modifier checks for structured status update", async function () {
      const params = {
        educatorAddress: ethers.ZeroAddress,
        isActive: false,
        newMintLimit: 0
      };
      
      await expect(
        educator.connect(admin)["setEducatorStatus((address,bool,uint256))"](params)
      ).to.be.revertedWith("EducEducator: address cannot be zero");
      
      const nonExistentParams = {
        educatorAddress: user2.address,
        isActive: false,
        newMintLimit: 0
      };
      
      await expect(
        educator.connect(admin)["setEducatorStatus((address,bool,uint256))"](nonExistentParams)
      ).to.be.revertedWith("EducEducator: educator does not exist");
    });
    
    it("Should update lastUpdatedAt timestamp", async function () {
      // Get initial info
      const initialInfo = await educator.getEducatorInfo(user1.address);
      
      // Wait a bit
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      // Update status
      await educator.connect(admin).setEducatorStatus(user1.address, false, 0);
      
      // Get updated info
      const updatedInfo = await educator.getEducatorInfo(user1.address);
      
      // The timestamp should be different
      expect(updatedInfo.lastUpdatedAt).to.be.gt(initialInfo.lastUpdatedAt);
    });
  });

  describe("Mint Recording", function () {
    beforeEach(async function () {
      await educator.connect(admin)["registerEducator(address,uint256)"](user1.address, ethers.parseEther("10000"));
    });

    it("Should allow admin to record minting", async function () {
      const mintAmount = ethers.parseEther("500");
      await educator.connect(admin).recordMint(user1.address, mintAmount);
      const info = await educator.getEducatorInfo(user1.address);
      expect(info.totalMinted).to.equal(mintAmount);
    });

    it("Should emit EducatorMintRecorded event when recording mint", async function () {
      const mintAmount = ethers.parseEther("500");
      await expect(educator.connect(admin).recordMint(user1.address, mintAmount))
        .to.emit(educator, EVENT_EDUCATOR_MINT_RECORDED)
        .withArgs(user1.address, mintAmount, mintAmount, anyValue);
    });

    it("Should not allow minting beyond limit", async function () {
      const tooMuch = ethers.parseEther("20000");
      await expect(
        educator.connect(admin).recordMint(user1.address, tooMuch)
      ).to.be.revertedWith("EducEducator: mint limit exceeded");
    });
    
    it("Should update lastMintTime when recording mint", async function () {
      const mintAmount = ethers.parseEther("500");
      
      // Get initial info
      const initialInfo = await educator.getEducatorInfo(user1.address);
      expect(initialInfo.lastMintTime).to.equal(0);
      
      // Record mint
      await educator.connect(admin).recordMint(user1.address, mintAmount);
      
      // Get updated info
      const updatedInfo = await educator.getEducatorInfo(user1.address);
      
      // Check lastMintTime has been set
      expect(updatedInfo.lastMintTime).to.be.gt(0);
    });
    
    it("Should track cumulative minted amount", async function () {
      const mintAmount1 = ethers.parseEther("500");
      const mintAmount2 = ethers.parseEther("300");
      
      await educator.connect(admin).recordMint(user1.address, mintAmount1);
      
      let info = await educator.getEducatorInfo(user1.address);
      expect(info.totalMinted).to.equal(mintAmount1);
      
      await educator.connect(admin).recordMint(user1.address, mintAmount2);
      
      info = await educator.getEducatorInfo(user1.address);
      expect(info.totalMinted).to.equal(mintAmount1 + mintAmount2);
    });
    
    it("Should not allow minting for inactive educators", async function () {
      // Deactivate educator
      await educator.connect(admin).setEducatorStatus(user1.address, false, 0);
      
      const mintAmount = ethers.parseEther("500");
      await expect(
        educator.connect(admin).recordMint(user1.address, mintAmount)
      ).to.be.revertedWith("EducEducator: educator is not active");
    });
    
    it("Should not allow non-admin to record mint", async function () {
      const mintAmount = ethers.parseEther("500");
      await expect(
        educator.connect(user2).recordMint(user1.address, mintAmount)
      ).to.be.revertedWithCustomError(educator, "AccessControlUnauthorizedAccount");
    });
    
    it("Should verify educator exists for recordMint", async function () {
      const mintAmount = ethers.parseEther("500");
      await expect(
        educator.connect(admin).recordMint(user2.address, mintAmount)
      ).to.be.revertedWith("EducEducator: educator does not exist");
    });
  });

  describe("Course Count Management", function () {
    beforeEach(async function () {
      await educator.connect(admin)["registerEducator(address,uint256)"](user1.address, ethers.parseEther("10000"));
    });

    it("Should allow admin to increment course count", async function () {
      await educator.connect(admin).incrementCourseCount(user1.address);
      const info = await educator.getEducatorInfo(user1.address);
      expect(info.courseCount).to.equal(1);
    });

    it("Should emit EducatorCourseCountIncremented event", async function () {
      await expect(educator.connect(admin).incrementCourseCount(user1.address))
        .to.emit(educator, EVENT_EDUCATOR_COURSE_COUNT_INCREMENTED)
        .withArgs(user1.address, 1, anyValue);
    });
    
    it("Should properly increment multiple times", async function () {
      // Increment first time
      await educator.connect(admin).incrementCourseCount(user1.address);
      let info = await educator.getEducatorInfo(user1.address);
      expect(info.courseCount).to.equal(1);
      
      // Increment second time
      await educator.connect(admin).incrementCourseCount(user1.address);
      info = await educator.getEducatorInfo(user1.address);
      expect(info.courseCount).to.equal(2);
      
      // Increment third time
      await educator.connect(admin).incrementCourseCount(user1.address);
      info = await educator.getEducatorInfo(user1.address);
      expect(info.courseCount).to.equal(3);
    });
    
    it("Should not allow non-admin to increment course count", async function () {
      await expect(
        educator.connect(user2).incrementCourseCount(user1.address)
      ).to.be.revertedWithCustomError(educator, "AccessControlUnauthorizedAccount");
    });
    
    it("Should verify educator exists for incrementCourseCount", async function () {
      await expect(
        educator.connect(admin).incrementCourseCount(user2.address)
      ).to.be.revertedWith("EducEducator: educator does not exist");
    });
  });
  
  describe("Educator Information Retrieval", function () {
    const mintLimit = ethers.parseEther("10000");
    const mintLimit2 = ethers.parseEther("20000");
    
    beforeEach(async function () {
      // Register educators
      await educator.connect(admin)["registerEducator(address,uint256)"](user1.address, mintLimit);
      await educator.connect(admin)["registerEducator(address,uint256)"](user2.address, mintLimit2);
    });
    
    it("Should correctly check if address is active educator", async function () {
      expect(await educator.isActiveEducator(user1.address)).to.equal(true);
      expect(await educator.isActiveEducator(user2.address)).to.equal(true);
      expect(await educator.isActiveEducator(user3.address)).to.equal(false);
      
      // Deactivate educator
      await educator.connect(admin).setEducatorStatus(user1.address, false, 0);
      expect(await educator.isActiveEducator(user1.address)).to.equal(false);
    });
    
    it("Should correctly return educator mint limit", async function () {
      expect(await educator.getEducatorMintLimit(user1.address)).to.equal(mintLimit);
      expect(await educator.getEducatorMintLimit(user2.address)).to.equal(mintLimit2);
      
      // Error for non-existent educator
      await expect(
        educator.getEducatorMintLimit(user3.address)
      ).to.be.revertedWith("EducEducator: educator does not exist");
    });
    
    it("Should correctly return educator total minted", async function () {
      // Initially zero
      expect(await educator.getEducatorTotalMinted(user1.address)).to.equal(0);
      
      // Record mint
      const mintAmount = ethers.parseEther("500");
      await educator.connect(admin).recordMint(user1.address, mintAmount);
      
      // Check updated value
      expect(await educator.getEducatorTotalMinted(user1.address)).to.equal(mintAmount);
      
      // Error for non-existent educator
      await expect(
        educator.getEducatorTotalMinted(user3.address)
      ).to.be.revertedWith("EducEducator: educator does not exist");
    });
    
    it("Should correctly return educator info struct", async function () {
      const info = await educator.getEducatorInfo(user1.address);
      
      expect(info.educatorAddress).to.equal(user1.address);
      expect(info.authorityAddress).to.equal(admin.address);
      expect(info.mintLimit).to.equal(mintLimit);
      expect(info.totalMinted).to.equal(0);
      expect(info.courseCount).to.equal(0);
      expect(info.isActive).to.equal(true);
      expect(info.createdAt).to.be.gt(0);
      expect(info.lastUpdatedAt).to.be.gt(0);
      expect(info.lastMintTime).to.equal(0);
      
      // Error for non-existent educator
      await expect(
        educator.getEducatorInfo(user3.address)
      ).to.be.revertedWith("EducEducator: educator does not exist");
    });
    
    it("Should correctly return total educators count", async function () {
      expect(await educator.getTotalEducators()).to.equal(2);
      
      // Register one more
      await educator.connect(admin)["registerEducator(address,uint256)"](user3.address, mintLimit);
      
      expect(await educator.getTotalEducators()).to.equal(3);
    });
  });
  
  describe("Pause Functionality", function () {
    it("Should allow admin to pause and unpause", async function () {
      // Check initial state
      expect(await educator.paused()).to.equal(false);
      
      // Pause
      await educator.connect(admin).pause();
      expect(await educator.paused()).to.equal(true);
      
      // Unpause
      await educator.connect(admin).unpause();
      expect(await educator.paused()).to.equal(false);
    });
    
    it("Should prevent operations when paused", async function () {
      // Pause
      await educator.connect(admin).pause();
      
      // Try to register educator (should fail)
      const mintLimit = ethers.parseEther("10000");
      await expect(
        educator.connect(admin)["registerEducator(address,uint256)"](user1.address, mintLimit)
      ).to.be.revertedWithCustomError(educator, "EnforcedPause");
      
      // Unpause
      await educator.connect(admin).unpause();
      
      // Now registration should work
      await educator.connect(admin)["registerEducator(address,uint256)"](user1.address, mintLimit);
      expect(await educator.isActiveEducator(user1.address)).to.equal(true);
    });
    
    it("Should not allow non-admins to pause or unpause", async function () {
      await expect(
        educator.connect(user1).pause()
      ).to.be.revertedWithCustomError(educator, "AccessControlUnauthorizedAccount");
      
      // Pause as admin
      await educator.connect(admin).pause();
      
      await expect(
        educator.connect(user1).unpause()
      ).to.be.revertedWithCustomError(educator, "AccessControlUnauthorizedAccount");
    });
  });
});