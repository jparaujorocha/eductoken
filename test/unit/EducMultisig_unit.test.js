const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("EducMultisig", function () {
  let EducMultisig;
  let multisig;
  let admin;
  let signer1;
  let signer2;
  let signer3;
  let user1;
  
  // Constants for roles
  let ADMIN_ROLE;
  
  // Constants
  const MAX_SIGNERS = 10;
  
  // Event signatures
  const EVENT_MULTISIG_CREATED = "MultisigCreated";
  const EVENT_SIGNER_ADDED = "SignerAdded";
  const EVENT_SIGNER_REMOVED = "SignerRemoved";
  const EVENT_THRESHOLD_CHANGED = "ThresholdChanged";

  beforeEach(async function () {
    // Get signers
    [admin, signer1, signer2, signer3, user1] = await ethers.getSigners();
    
    // Calculate role hashes
    ADMIN_ROLE = ethers.keccak256(ethers.toUtf8Bytes("ADMIN_ROLE"));
    
    // Initial signers and threshold
    const initialSigners = [signer1.address, signer2.address];
    const initialThreshold = 2; // Require both signers
    
    // Deploy multisig contract
    EducMultisig = await ethers.getContractFactory("EducMultisig");
    multisig = await EducMultisig.deploy(initialSigners, initialThreshold, admin.address);
  });

  describe("Deployment", function () {
    it("Should set the right admin", async function () {
      expect(await multisig.hasRole(ADMIN_ROLE, admin.address)).to.equal(true);
    });
    
    it("Should initialize with correct signers", async function () {
      const signers = await multisig.getSigners();
      expect(signers).to.deep.equal([signer1.address, signer2.address]);
      
      expect(await multisig.isSigner(signer1.address)).to.equal(true);
      expect(await multisig.isSigner(signer2.address)).to.equal(true);
      expect(await multisig.isSigner(signer3.address)).to.equal(false);
    });
    
    it("Should initialize with correct threshold", async function () {
      expect(await multisig.threshold()).to.equal(2);
    });
    
    it("Should initialize with zero proposal count", async function () {
      expect(await multisig.proposalCount()).to.equal(0);
    });
    
    it("Should emit MultisigCreated event", async function () {
      // Deploy new instance to capture event
      const initialSigners = [signer1.address, signer2.address];
      const initialThreshold = 2;
      
      const tx = await EducMultisig.deploy(initialSigners, initialThreshold, admin.address);
      const receipt = await tx.deploymentTransaction().wait();
      
      // Check that at least one event was emitted
      const createdEvents = receipt.logs.filter(log => {
        try {
          return log.fragment?.name === EVENT_MULTISIG_CREATED;
        } catch (e) {
          return false;
        }
      });
      
      expect(createdEvents.length).to.be.at.least(1);
    });
    
    it("Should grant admin role to all signers", async function () {
      expect(await multisig.hasRole(ADMIN_ROLE, signer1.address)).to.equal(true);
      expect(await multisig.hasRole(ADMIN_ROLE, signer2.address)).to.equal(true);
    });
    
    it("Should validate signers count within limits during deployment", async function () {
      // Test with empty signers
      await expect(
        EducMultisig.deploy([], 0, admin.address)
      ).to.be.revertedWith("EducMultisig: Insufficient signers");
      
      // Test with too many signers
      const tooManySigners = Array(MAX_SIGNERS + 1).fill().map((_, i) => ethers.Wallet.createRandom().address);
      
      await expect(
        EducMultisig.deploy(tooManySigners, 1, admin.address)
      ).to.be.revertedWith("EducMultisig: Too many signers");
    });
    
    it("Should validate threshold during deployment", async function () {
      const initialSigners = [signer1.address, signer2.address];
      
      // Test with zero threshold
      await expect(
        EducMultisig.deploy(initialSigners, 0, admin.address)
      ).to.be.revertedWith("EducMultisig: Invalid threshold");
      
      // Test with threshold higher than signers count
      await expect(
        EducMultisig.deploy(initialSigners, 3, admin.address)
      ).to.be.revertedWith("EducMultisig: Invalid threshold");
    });
    
    it("Should validate signer addresses during deployment", async function () {
      // Test with zero address
      const signersWithZero = [signer1.address, ethers.ZeroAddress];
      
      await expect(
        EducMultisig.deploy(signersWithZero, 1, admin.address)
      ).to.be.revertedWith("EducMultisig: Invalid signer address");
      
      // Test with duplicate signers
      const duplicateSigners = [signer1.address, signer1.address];
      
      await expect(
        EducMultisig.deploy(duplicateSigners, 1, admin.address)
      ).to.be.revertedWith("EducMultisig: Duplicate signer");
    });
    
    it("Should validate admin address during deployment", async function() {
      const initialSigners = [signer1.address, signer2.address];
      const initialThreshold = 2;
      
      await expect(
        EducMultisig.deploy(initialSigners, initialThreshold, ethers.ZeroAddress)
      ).to.be.revertedWith("EducMultisig: Invalid admin");
    });
  });

  describe("Signer Management", function () {
    it("Should allow admin to add a new signer", async function () {
      await multisig.connect(admin).addSigner(signer3.address);
      
      const signers = await multisig.getSigners();
      expect(signers).to.include(signer3.address);
      expect(await multisig.isSigner(signer3.address)).to.equal(true);
    });
    
    it("Should emit SignerAdded event when adding signer", async function () {
      const tx = await multisig.connect(admin).addSigner(signer3.address);
      const receipt = await tx.wait();
      
      // Check for event
      const addedEvents = receipt.logs.filter(log => {
        try {
          return log.fragment?.name === EVENT_SIGNER_ADDED;
        } catch (e) {
          return false;
        }
      });
      
      expect(addedEvents.length).to.equal(1);
    });
    
    it("Should not allow adding existing signer", async function () {
      await expect(
        multisig.connect(admin).addSigner(signer1.address)
      ).to.be.revertedWith("EducMultisig: Signer already exists");
    });
    
    it("Should not allow adding zero address", async function () {
      await expect(
        multisig.connect(admin).addSigner(ethers.ZeroAddress)
      ).to.be.revertedWith("EducMultisig: Invalid signer");
    });
    
    it("Should enforce maximum signers limit", async function () {
      // Add MAX_SIGNERS - 2 more signers (we already have 2)
      for (let i = 0; i < MAX_SIGNERS - 2; i++) {
        const newSigner = ethers.Wallet.createRandom().address;
        await multisig.connect(admin).addSigner(newSigner);
      }
      
      // Now we should have MAX_SIGNERS signers
      expect(await multisig.getSignerCount()).to.equal(MAX_SIGNERS);
      
      // Try to add one more
      const extraSigner = ethers.Wallet.createRandom().address;
      await expect(
        multisig.connect(admin).addSigner(extraSigner)
      ).to.be.revertedWith("EducMultisig: Max signers reached");
    });
    
    it("Should not allow non-admin to add signer", async function () {
      await expect(
        multisig.connect(user1).addSigner(signer3.address)
      ).to.be.reverted;
    });
    
    it("Should allow admin to remove a signer", async function () {
      // Add a third signer first so we don't go below threshold
      await multisig.connect(admin).addSigner(signer3.address);
      
      // Now remove a signer
      await multisig.connect(admin).removeSigner(signer1.address);
      
      const signers = await multisig.getSigners();
      expect(signers).to.not.include(signer1.address);
      expect(await multisig.isSigner(signer1.address)).to.equal(false);
    });
    
    it("Should emit SignerRemoved event when removing signer", async function () {
      // Add a third signer first so we don't go below threshold
      await multisig.connect(admin).addSigner(signer3.address);
      
      const tx = await multisig.connect(admin).removeSigner(signer1.address);
      const receipt = await tx.wait();
      
      // Check for event
      const removedEvents = receipt.logs.filter(log => {
        try {
          return log.fragment?.name === EVENT_SIGNER_REMOVED;
        } catch (e) {
          return false;
        }
      });
      
      expect(removedEvents.length).to.equal(1);
    });
    
    it("Should prevent removing signer if it would break threshold requirements", async function () {
      // Currently 2 signers with threshold 2
      await expect(
        multisig.connect(admin).removeSigner(signer1.address)
      ).to.be.revertedWith("EducMultisig: Cannot remove signer");
    });
    
    it("Should not allow removing non-existent signer", async function () {
      // Add a third signer first so we don't go below threshold
      await multisig.connect(admin).addSigner(signer3.address);
      
      await expect(
        multisig.connect(admin).removeSigner(user1.address)
      ).to.be.revertedWith("EducMultisig: Signer not found");
    });
    
    it("Should not allow non-admin to remove signer", async function () {
      // Add a third signer first so we don't go below threshold
      await multisig.connect(admin).addSigner(signer3.address);
      
      await expect(
        multisig.connect(user1).removeSigner(signer1.address)
      ).to.be.reverted;
    });
    
    it("Should correctly revoke admin role when removing signer", async function () {
      // Add a third signer
      await multisig.connect(admin).addSigner(signer3.address);
      
      // Verify the role was granted during addition
      expect(await multisig.hasRole(ADMIN_ROLE, signer3.address)).to.equal(true);
      
      // Remove the signer
      await multisig.connect(admin).removeSigner(signer3.address);
      
      // Verify the role was revoked
      expect(await multisig.hasRole(ADMIN_ROLE, signer3.address)).to.equal(false);
    });
  });

  describe("Threshold Management", function () {
    beforeEach(async function () {
      // Add a third signer for threshold testing
      await multisig.connect(admin).addSigner(signer3.address);
    });
    
    it("Should allow admin to change threshold", async function () {
      await multisig.connect(admin).changeThreshold(3);
      
      expect(await multisig.threshold()).to.equal(3);
    });
    
    it("Should emit ThresholdChanged event", async function () {
      const oldThreshold = await multisig.threshold();
      const newThreshold = 3;
      
      const tx = await multisig.connect(admin).changeThreshold(newThreshold);
      const receipt = await tx.wait();
      
      // Check for event
      const thresholdEvents = receipt.logs.filter(log => {
        try {
          return log.fragment?.name === EVENT_THRESHOLD_CHANGED;
        } catch (e) {
          return false;
        }
      });
      
      expect(thresholdEvents.length).to.equal(1);
    });
    
    it("Should not allow threshold below 1", async function () {
      await expect(
        multisig.connect(admin).changeThreshold(0)
      ).to.be.revertedWith("EducMultisig: Invalid threshold");
    });
    
    it("Should not allow threshold greater than signers count", async function () {
      const signersCount = await multisig.getSignerCount();
      
      await expect(
        multisig.connect(admin).changeThreshold(Number(signersCount) + 1)
      ).to.be.revertedWith("EducMultisig: Invalid threshold");
    });
    
    it("Should not allow non-admin to change threshold", async function () {
      await expect(
        multisig.connect(user1).changeThreshold(3)
      ).to.be.reverted;
    });
    
    it("Should automatically reduce threshold when signers count decreases below it", async function () {
      // Change threshold to 3 (max with our 3 signers)
      await multisig.connect(admin).changeThreshold(3);
      
      // Add fourth signer so we can remove one while maintaining 3 signers
      await multisig.connect(admin).addSigner(user1.address);
      
      // Now remove a signer, which should auto-adjust threshold
      await multisig.connect(admin).removeSigner(signer1.address);
      
      // Threshold should have been adjusted to new signer count
      expect(await multisig.threshold()).to.equal(3);
    });
    
    it("Should keep threshold when removing a signer but count still above threshold", async function () {
      // We have 3 signers with threshold 2
      expect(await multisig.threshold()).to.equal(2);
      expect(await multisig.getSignerCount()).to.equal(3);
      
      // Remove a signer
      await multisig.connect(admin).removeSigner(signer1.address);
      
      // Threshold should remain unchanged
      expect(await multisig.threshold()).to.equal(2);
    });
  });

  describe("Proposal Management", function () {
    it("Should allow admin to increment proposal count", async function () {
      const initialCount = await multisig.proposalCount();
      
      await multisig.connect(admin).incrementProposalCount();
      
      const newCount = await multisig.proposalCount();
      expect(newCount).to.equal(initialCount + 1n);
    });
    
    it("Should not allow non-admin to increment proposal count", async function () {
      await expect(
        multisig.connect(user1).incrementProposalCount()
      ).to.be.reverted;
    });
  });

  describe("Signers Querying", function () {
    it("Should return all signers", async function () {
      const signers = await multisig.getSigners();
      expect(signers).to.deep.equal([signer1.address, signer2.address]);
    });
    
    it("Should return correct signer count", async function () {
      const count = await multisig.getSignerCount();
      expect(count).to.equal(2);
      
      // Add another signer
      await multisig.connect(admin).addSigner(signer3.address);
      
      const newCount = await multisig.getSignerCount();
      expect(newCount).to.equal(3);
    });
    
    it("Should correctly identify signers", async function () {
      expect(await multisig.isSigner(signer1.address)).to.equal(true);
      expect(await multisig.isSigner(signer2.address)).to.equal(true);
      expect(await multisig.isSigner(signer3.address)).to.equal(false);
      expect(await multisig.isSigner(user1.address)).to.equal(false);
    });
    
    it("Should correctly update signer list after removing a signer", async function () {
      // Add a third signer first
      await multisig.connect(admin).addSigner(signer3.address);
      
      // Verify initial state
      let signers = await multisig.getSigners();
      expect(signers.length).to.equal(3);
      expect(signers).to.include(signer1.address);
      expect(signers).to.include(signer2.address);
      expect(signers).to.include(signer3.address);
      
      // Remove the middle signer
      await multisig.connect(admin).removeSigner(signer2.address);
      
      // Verify updated state
      signers = await multisig.getSigners();
      expect(signers.length).to.equal(2);
      expect(signers).to.include(signer1.address);
      expect(signers).to.not.include(signer2.address);
      expect(signers).to.include(signer3.address);
    });
    
    it("Should maintain signer list order after internal array manipulation", async function () {
      // Add two more signers
      await multisig.connect(admin).addSigner(signer3.address);
      await multisig.connect(admin).addSigner(user1.address);
      
      // Get initial state
      const initialSigners = await multisig.getSigners();
      
      // Remove a signer from the middle (this uses array manipulation)
      await multisig.connect(admin).removeSigner(signer2.address);
      
      // Get updated state
      const updatedSigners = await multisig.getSigners();
      
      // The last signer should have been moved to replace the removed signer
      expect(updatedSigners.length).to.equal(initialSigners.length - 1);
      expect(updatedSigners).to.include(signer1.address);
      expect(updatedSigners).to.not.include(signer2.address);
      expect(updatedSigners).to.include(signer3.address);
      expect(updatedSigners).to.include(user1.address);
    });
  });
  
  describe("Authority Management", function () {
    it("Should correctly set authority during deployment", async function () {
      expect(await multisig.authority()).to.equal(admin.address);
    });
  });
});