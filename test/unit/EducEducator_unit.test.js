const { expect } = require("chai");
const { ethers } = require("hardhat");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");

describe("EducEducator", function () {
  let EducEducator;
  let educator;
  let admin;
  let user1;
  let user2;

  let ADMIN_ROLE;

  const EVENT_EDUCATOR_REGISTERED = "EducatorRegistered";
  const EVENT_EDUCATOR_STATUS_UPDATED = "EducatorStatusUpdated";
  const EVENT_EDUCATOR_MINT_RECORDED = "EducatorMintRecorded";
  const EVENT_EDUCATOR_COURSE_COUNT_INCREMENTED = "EducatorCourseCountIncremented";

  beforeEach(async function () {
    [admin, user1, user2] = await ethers.getSigners();

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
        educator.connect(admin)["registerEducator(address,uint256)"](user1.address, max + 1n)
      ).to.be.revertedWith("EducEducator: invalid mint limit");
    });

    it("Should not allow non-admin to register educators", async function () {
      const mintLimit = ethers.parseEther("10000");
      await expect(
        educator.connect(user1)["registerEducator(address,uint256)"](user2.address, mintLimit)
      ).to.be.revertedWithCustomError(educator, "AccessControlUnauthorizedAccount");
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
  });
});
