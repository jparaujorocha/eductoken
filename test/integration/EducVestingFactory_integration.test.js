const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("EducVestingFactory Integration Tests", function () {
  let vestingFactory;
  let token1;
  let token2;
  let admin;
  let treasury;
  let beneficiary1;

  beforeEach(async function () {
    [admin, treasury, beneficiary1, _] = await ethers.getSigners();

    // Deploy multiple tokens
    const TokenFactory = await ethers.getContractFactory("EducToken");
    token1 = await TokenFactory.deploy(admin.address);
    token2 = await TokenFactory.deploy(admin.address);

    // Deploy Vesting Factory
    const VestingFactoryFactory = await ethers.getContractFactory("EducVestingFactory");
    vestingFactory = await VestingFactoryFactory.deploy(admin.address);
  });

  describe("Vesting Contract Creation", function () {
    it("Should create a vesting contract", async function() {
      // Create vesting contract
      const tx = await vestingFactory.createVestingContract(
        token1.target,
        treasury.address
      );
      
      // Wait for transaction to be mined
      await tx.wait();
      
      // Get vesting contracts for token1
      const contractsForToken = await vestingFactory.getVestingContractsForToken(token1.target);
      
      // Verify there is at least one contract
      expect(contractsForToken.length).to.be.greaterThan(0);
      
      // Verify the contract address is valid
      expect(ethers.isAddress(contractsForToken[0])).to.be.true;
    });

    it("Should prevent creating vesting contract with zero addresses", async function () {
      await expect(
        vestingFactory.createVestingContract(
          ethers.ZeroAddress, 
          treasury.address
        )
      ).to.be.revertedWith("EducVestingFactory: Token cannot be zero address");

      await expect(
        vestingFactory.createVestingContract(
          token1.target, 
          ethers.ZeroAddress
        )
      ).to.be.revertedWith("EducVestingFactory: Treasury cannot be zero address");
    });
  });

  describe("Vesting Contract Management", function () {
    it("Should provide accurate vesting contract counts", async function () {
      // Create multiple vesting contracts across different tokens
      await vestingFactory.createVestingContract(token1.target, treasury.address);
      await vestingFactory.createVestingContract(token1.target, treasury.address);
      await vestingFactory.createVestingContract(token2.target, treasury.address);

      // Check total contracts count
      const totalContractsCount = await vestingFactory.getTotalVestingContractsCount();
      expect(totalContractsCount).to.equal(3);

      // Check token-specific contracts count
      const token1ContractsCount = await vestingFactory.getVestingContractsCountForToken(token1.target);
      const token2ContractsCount = await vestingFactory.getVestingContractsCountForToken(token2.target);

      expect(token1ContractsCount).to.equal(2);
      expect(token2ContractsCount).to.equal(1);
    });

    it("Should prevent non-admin from creating vesting contracts", async function () {
      const [, nonAdmin] = await ethers.getSigners();

      await expect(
        vestingFactory.connect(nonAdmin).createVestingContract(
          token1.target, 
          treasury.address
        )
      ).to.be.reverted;
    });
  });

  describe("Event Emission and Tracking", function () {
    it("Should emit event when creating vesting contract", async function () {
      // Create vesting contract and verify event is emitted
      await expect(
        vestingFactory.createVestingContract(token1.target, treasury.address)
      ).to.emit(vestingFactory, "VestingContractCreated");
    });
  });
});