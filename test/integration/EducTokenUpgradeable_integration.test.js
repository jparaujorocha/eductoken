const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("EducTokenUpgradeable Integration Tests", function () {
  let token;
  let admin;
  let minter;
  let user1;

  beforeEach(async function () {
    // Get signers
    [admin, minter, user1] = await ethers.getSigners();

    // Deploy upgradeable token contract with specific initialization
    const TokenFactory = await ethers.getContractFactory("EducTokenUpgradeable");
    token = await upgrades.deployProxy(TokenFactory, [admin.address], {
      initializer: "initialize(address)",
      kind: "uups"
    });
    await token.waitForDeployment();
  });

  describe("Basic Token Functionality", function () {
    it("Should deploy with correct initial configuration", async function () {
      // Check token name and symbol
      expect(await token.name()).to.equal("EducToken");
      expect(await token.symbol()).to.equal("EDUC");

      // Check initial supply
      const initialSupply = ethers.parseEther("10000000");
      const adminBalance = await token.balanceOf(admin.address);
      
      expect(adminBalance).to.equal(initialSupply);
      expect(await token.totalMinted()).to.equal(initialSupply);
    });

    it("Should allow admin to grant minter role", async function() {
      // Grant minter role to minter address
      await token.connect(admin).grantRole(await token.MINTER_ROLE(), minter.address);
      
      // Verify minter role
      expect(await token.hasRole(await token.MINTER_ROLE(), minter.address)).to.be.true;
    });

    it("Should allow minter to mint tokens", async function() {
      // Grant minter role
      await token.connect(admin).grantRole(await token.MINTER_ROLE(), minter.address);
      
      // Mint tokens
      const mintAmount = ethers.parseEther("1000");
      await token.connect(minter).mint(user1.address, mintAmount);
      
      // Check balance
      expect(await token.balanceOf(user1.address)).to.equal(mintAmount);
    });
  });
});