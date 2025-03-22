const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("EducRoles Integration Tests", function () {
  let rolesContract;

  beforeEach(async function () {
    const EducRolesFactory = await ethers.getContractFactory("EducRoles");
    rolesContract = await EducRolesFactory.deploy();
  });

  describe("Role Validation and Management", function () {
    it("Should validate roles", async function () {
        const roles = [
          ethers.keccak256(ethers.toUtf8Bytes("ADMIN_ROLE")),
          ethers.keccak256(ethers.toUtf8Bytes("EDUCATOR_ROLE")),
          // Add other predefined roles
        ];
        
        for (const role of roles) {
          const isValid = await rolesContract.hasRole(role, ethers.ZeroAddress);
          // Adjust validation based on actual contract implementation
          expect(isValid).to.be.false;
        }
      });

    it("Should return correct role names", async function () {
      const roleNames = [
        "Admin",
        "Educator",
        "Minter",
        "Pauser", 
        "Upgrader",
        "Emergency"
      ];

      const roles = await rolesContract.getAllRoles();
      
      for (let i = 0; i < roles.length; i++) {
        const roleName = await rolesContract.getRoleName(roles[i]);
        expect(roleName).to.equal(roleNames[i]);
      }
    });

    it("Should handle unknown roles gracefully", async function () {
      const unknownRole = ethers.keccak256(ethers.toUtf8Bytes("UNKNOWN_ROLE"));
      
      expect(await rolesContract.isValidRole(unknownRole)).to.be.false;
      
      const roleName = await rolesContract.getRoleName(unknownRole);
      expect(roleName).to.equal("Unknown");
    });
  });
});