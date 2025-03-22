// EducCourse_unit.test.js
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("EducCourse", function () {
  let EducCourse;
  let course;
  let EducEducator;
  let educator;
  let admin;
  let user1;
  let user2;
  
  // Constants for roles
  let ADMIN_ROLE;
  let EDUCATOR_ROLE;
  
  // Event signatures
  const EVENT_COURSE_CREATED = "CourseCreated";
  const EVENT_COURSE_UPDATED = "CourseUpdated";
  const EVENT_COURSE_COMPLETION_TRACKED = "CourseCompletionTracked";

  beforeEach(async function () {
    // Get signers
    [admin, user1, user2] = await ethers.getSigners();
    
    // Deploy educator contract first
    EducEducator = await ethers.getContractFactory("EducEducator");
    educator = await EducEducator.deploy(admin.address);
    
    // Deploy course contract
    EducCourse = await ethers.getContractFactory("EducCourse");
    course = await EducCourse.deploy(admin.address, educator.target);
    
    // Calculate role hashes directly from the contract's constant
    const educRolesFactory = await ethers.getContractFactory("EducRoles");
    const educRoles = await educRolesFactory.deploy();
    ADMIN_ROLE = await educRoles.ADMIN_ROLE();
    EDUCATOR_ROLE = await educRoles.EDUCATOR_ROLE();
    
    // Register user1 as an educator for testing
    await educator.connect(admin)["registerEducator(address,uint256)"](user1.address, ethers.parseEther("10000"));
    
    // Critical: Grant EDUCATOR_ROLE to the EducCourse contract in the educator contract
    await educator.grantRole(EDUCATOR_ROLE, course.target);
    
    // Critical: Grant ADMIN_ROLE to the EducCourse contract in the educator contract
    // This is the key fix - the EducCourse contract needs ADMIN_ROLE to call incrementCourseCount
    await educator.grantRole(ADMIN_ROLE, course.target);
    
    // Grant roles to users in course contract
    await course.grantRole(ADMIN_ROLE, admin.address);
    await course.grantRole(EDUCATOR_ROLE, admin.address);
    await course.grantRole(EDUCATOR_ROLE, user1.address);    
  });

  describe("Deployment", function () {
    it("Should set the right admin", async function () {
      expect(await course.hasRole(ADMIN_ROLE, admin.address)).to.equal(true);
    });
    
    it("Should set the educator contract correctly", async function () {
      // Educator contract address should be stored
      expect(await course.educatorContract()).to.equal(educator.target);
    });
    
    it("Should initialize with zero courses", async function () {
      expect(await course.getTotalCourses()).to.equal(0);
    });
  });

  describe("Course Creation", function () {
    it("Should allow active educator to create a course", async function () {
      // Double-check the role is correctly set
      expect(await educator.hasRole(EDUCATOR_ROLE, course.target)).to.equal(true);
      
      const courseId = "CS101";
      const courseName = "Introduction to Computer Science";
      const rewardAmount = ethers.parseEther("50");
      const metadataHash = ethers.keccak256(ethers.toUtf8Bytes("metadata"));
      
      await course.connect(user1)["createCourse(string,string,uint256,bytes32)"](courseId, courseName, rewardAmount, metadataHash);
      
      // Check if course is active
      expect(await course.isCourseActive(user1.address, courseId)).to.equal(true);
      
      // Get course info
      const courseInfo = await course.getCourseInfo(user1.address, courseId);
      expect(courseInfo.courseId).to.equal(courseId);
      expect(courseInfo.courseName).to.equal(courseName);
      expect(courseInfo.educator).to.equal(user1.address);
      expect(courseInfo.rewardAmount).to.equal(rewardAmount);
      expect(courseInfo.isActive).to.equal(true);
      expect(courseInfo.metadataHash).to.equal(metadataHash);
    });
    
    it("Should emit CourseCreated event when creating a course", async function () {
      const courseId = "CS101";
      const courseName = "Introduction to Computer Science";
      const rewardAmount = ethers.parseEther("50");
      const metadataHash = ethers.keccak256(ethers.toUtf8Bytes("metadata"));
      
      await expect(course.connect(user1)["createCourse(string,string,uint256,bytes32)"](courseId, courseName, rewardAmount, metadataHash))
        .to.emit(course, EVENT_COURSE_CREATED);
    });
    
    it("Should increment educator's course count", async function () {
      const initialCourseCount = (await educator.getEducatorInfo(user1.address)).courseCount;
      
      const courseId = "CS101";
      const courseName = "Introduction to Computer Science";
      const rewardAmount = ethers.parseEther("50");
      const metadataHash = ethers.keccak256(ethers.toUtf8Bytes("metadata"));
      
      await course.connect(user1)["createCourse(string,string,uint256,bytes32)"](courseId, courseName, rewardAmount, metadataHash);
      
      const newCourseCount = (await educator.getEducatorInfo(user1.address)).courseCount;
      expect(newCourseCount).to.equal(initialCourseCount + BigInt(1));
    });
    
    it("Should increment total courses count", async function () {
      const initialCount = await course.getTotalCourses();
      
      const courseId = "CS101";
      const courseName = "Introduction to Computer Science";
      const rewardAmount = ethers.parseEther("50");
      const metadataHash = ethers.keccak256(ethers.toUtf8Bytes("metadata"));
      
      await course.connect(user1)["createCourse(string,string,uint256,bytes32)"](courseId, courseName, rewardAmount, metadataHash);
      
      const newCount = await course.getTotalCourses();
      expect(newCount).to.equal(initialCount + BigInt(1));
    });
    
    it("Should not allow non-educator to create a course", async function () {
      const courseId = "CS101";
      const courseName = "Introduction to Computer Science";
      const rewardAmount = ethers.parseEther("50");
      const metadataHash = ethers.keccak256(ethers.toUtf8Bytes("metadata"));
      
      // User2 is not registered as an educator
      await expect(
        course.connect(user2)["createCourse(string,string,uint256,bytes32)"](courseId, courseName, rewardAmount, metadataHash)
      ).to.be.revertedWith("EducCourse: Caller not an active educator");
    });
    
    it("Should not allow creating a course with empty ID", async function () {
      const courseId = "";
      const courseName = "Introduction to Computer Science";
      const rewardAmount = ethers.parseEther("50");
      const metadataHash = ethers.keccak256(ethers.toUtf8Bytes("metadata"));
      
      await expect(
        course.connect(user1)["createCourse(string,string,uint256,bytes32)"](courseId, courseName, rewardAmount, metadataHash)
      ).to.be.revertedWith("EducCourse: Invalid course ID");
    });
    
    it("Should not allow creating a course with empty name", async function () {
      const courseId = "CS101";
      const courseName = "";
      const rewardAmount = ethers.parseEther("50");
      const metadataHash = ethers.keccak256(ethers.toUtf8Bytes("metadata"));
      
      await expect(
        course.connect(user1)["createCourse(string,string,uint256,bytes32)"](courseId, courseName, rewardAmount, metadataHash)
      ).to.be.revertedWith("EducCourse: Invalid course name");
    });
    
    it("Should not allow zero reward amount", async function () {
      const courseId = "CS101";
      const courseName = "Introduction to Computer Science";
      const rewardAmount = 0;
      const metadataHash = ethers.keccak256(ethers.toUtf8Bytes("metadata"));
      
      await expect(
        course.connect(user1)["createCourse(string,string,uint256,bytes32)"](courseId, courseName, rewardAmount, metadataHash)
      ).to.be.revertedWith("EducCourse: Invalid reward amount");
    });
    
    it("Should not allow creating a duplicate course", async function () {
      const courseId = "CS101";
      const courseName = "Introduction to Computer Science";
      const rewardAmount = ethers.parseEther("50");
      const metadataHash = ethers.keccak256(ethers.toUtf8Bytes("metadata"));
      
      // Create first course
      await course.connect(user1)["createCourse(string,string,uint256,bytes32)"](courseId, courseName, rewardAmount, metadataHash);
      
      // Attempt to create duplicate course
      await expect(
        course.connect(user1)["createCourse(string,string,uint256,bytes32)"](courseId, courseName, rewardAmount, metadataHash)
      ).to.be.revertedWith("EducCourse: Course already exists");
    });
    
    it("Should allow creating a course with structured parameters", async function () {
      // Using the structured params version
      const params = {
        courseId: "CS101",
        courseName: "Introduction to Computer Science",
        rewardAmount: ethers.parseEther("50"),
        metadataHash: ethers.keccak256(ethers.toUtf8Bytes("metadata"))
      };
      
      await course.connect(user1)["createCourse((string,string,uint256,bytes32))"](params);
      
      // Check if course is active
      expect(await course.isCourseActive(user1.address, params.courseId)).to.equal(true);
    });
  });

  describe("Course Updates", function () {
    beforeEach(async function () {
      // Create a course
      const courseId = "CS101";
      const courseName = "Introduction to Computer Science";
      const rewardAmount = ethers.parseEther("50");
      const metadataHash = ethers.keccak256(ethers.toUtf8Bytes("metadata"));
      
      await course.connect(user1)["createCourse(string,string,uint256,bytes32)"](courseId, courseName, rewardAmount, metadataHash);
    });
    
    it("Should allow course owner to update course", async function () {
      const courseId = "CS101";
      const newCourseName = "Advanced Computer Science";
      const newRewardAmount = ethers.parseEther("75");
      const isActive = true;
      const newMetadataHash = ethers.keccak256(ethers.toUtf8Bytes("new-metadata"));
      const changeDescription = "Updated course content and rewards";
      
      await course.connect(user1)["updateCourse(string,string,uint256,bool,bytes32,string)"](
        courseId,
        newCourseName,
        newRewardAmount,
        isActive,
        newMetadataHash,
        changeDescription
      );
      
      // Get updated course info
      const courseInfo = await course.getCourseInfo(user1.address, courseId);
      expect(courseInfo.courseName).to.equal(newCourseName);
      expect(courseInfo.rewardAmount).to.equal(newRewardAmount);
      expect(courseInfo.isActive).to.equal(isActive);
      expect(courseInfo.metadataHash).to.equal(newMetadataHash);
      expect(courseInfo.version).to.equal(2); // Incremented version
    });
    
    it("Should emit CourseUpdated event when updating a course", async function () {
      const courseId = "CS101";
      const newCourseName = "Advanced Computer Science";
      const newRewardAmount = ethers.parseEther("75");
      const isActive = true;
      const newMetadataHash = ethers.keccak256(ethers.toUtf8Bytes("new-metadata"));
      const changeDescription = "Updated course content and rewards";
      
      await expect(course.connect(user1)["updateCourse(string,string,uint256,bool,bytes32,string)"](
        courseId,
        newCourseName,
        newRewardAmount,
        isActive,
        newMetadataHash,
        changeDescription
      ))
        .to.emit(course, EVENT_COURSE_UPDATED);
    });
    
    it("Should allow partial course updates", async function () {
      const courseId = "CS101";
      const originalCourse = await course.getCourseInfo(user1.address, courseId);
      
      // Only update the name, leave other fields unchanged
      await course.connect(user1)["updateCourse(string,string,uint256,bool,bytes32,string)"](
        courseId,
        "New Course Name",
        0, // 0 means keep current reward
        originalCourse.isActive,
        ethers.ZeroHash, // Zero hash means keep current metadata
        "Updated course name only"
      );
      
      // Get updated course info
      const updatedCourse = await course.getCourseInfo(user1.address, courseId);
      expect(updatedCourse.courseName).to.equal("New Course Name");
      expect(updatedCourse.rewardAmount).to.equal(originalCourse.rewardAmount);
      expect(updatedCourse.metadataHash).to.equal(originalCourse.metadataHash);
    });
    
    it("Should track course history", async function () {
      const courseId = "CS101";
      
      // Make first update
      await course.connect(user1)["updateCourse(string,string,uint256,bool,bytes32,string)"](
        courseId,
        "Updated Course Name",
        ethers.parseEther("60"),
        true,
        ethers.keccak256(ethers.toUtf8Bytes("metadata-v2")),
        "First update"
      );
      
      // Make second update
      await course.connect(user1)["updateCourse(string,string,uint256,bool,bytes32,string)"](
        courseId,
        "Final Course Name",
        ethers.parseEther("70"),
        false,
        ethers.keccak256(ethers.toUtf8Bytes("metadata-v3")),
        "Second update"
      );
      
      // Check history count
      const historyCount = await course.getCourseHistoryCount(user1.address, courseId);
      expect(historyCount).to.equal(2);
      
      // Check first history entry
      const historyV2 = await course.getCourseHistory(user1.address, courseId, 2);
      expect(historyV2.version).to.equal(2);
      expect(historyV2.previousName).to.equal("Introduction to Computer Science");
      expect(historyV2.changeDescription).to.equal("First update");
      
      // Check second history entry
      const historyV3 = await course.getCourseHistory(user1.address, courseId, 3);
      expect(historyV3.version).to.equal(3);
      expect(historyV3.previousName).to.equal("Updated Course Name");
      expect(historyV3.changeDescription).to.equal("Second update");
    });
    
    it("Should not allow non-owner to update course", async function () {
      const courseId = "CS101";
      
      // User2 is not the course owner
      await expect(
        course.connect(user2)["updateCourse(string,string,uint256,bool,bytes32,string)"](
          courseId,
          "Hijacked Course",
          ethers.parseEther("10"),
          true,
          ethers.ZeroHash,
          "Malicious update"
        )
      ).to.be.revertedWith("EducCourse: Course not found or not owner");
    });
    
    it("Should allow updating a course with structured parameters", async function () {
      // Using the structured params version
      const params = {
        courseId: "CS101",
        courseName: "Advanced Computer Science",
        rewardAmount: ethers.parseEther("75"),
        isActive: true,
        metadataHash: ethers.keccak256(ethers.toUtf8Bytes("new-metadata")),
        changeDescription: "Updated course content and rewards"
      };
      
      await course.connect(user1)["updateCourse((string,string,uint256,bool,bytes32,string))"](params);
      
      // Get updated course info
      const courseInfo = await course.getCourseInfo(user1.address, params.courseId);
      expect(courseInfo.courseName).to.equal(params.courseName);
      expect(courseInfo.rewardAmount).to.equal(params.rewardAmount);
    });
  });

  describe("Course Completion Tracking", function () {
    beforeEach(async function () {
      // Create a course
      const courseId = "CS101";
      const courseName = "Introduction to Computer Science";
      const rewardAmount = ethers.parseEther("50");
      const metadataHash = ethers.keccak256(ethers.toUtf8Bytes("metadata"));
      
      await course.connect(user1)["createCourse(string,string,uint256,bytes32)"](courseId, courseName, rewardAmount, metadataHash);
    });
    
    it("Should allow admin to increment course completion count", async function () {
      const courseId = "CS101";
      
      // Get initial completion count
      const initialCourse = await course.getCourseInfo(user1.address, courseId);
      expect(initialCourse.completionCount).to.equal(0);
      
      // Increment completion count
      await course.connect(admin).incrementCompletionCount(user1.address, courseId);
      
      // Get updated completion count
      const updatedCourse = await course.getCourseInfo(user1.address, courseId);
      expect(updatedCourse.completionCount).to.equal(1);
    });
    
    it("Should emit CourseCompletionTracked event", async function () {
      const courseId = "CS101";
      
      await expect(course.connect(admin).incrementCompletionCount(user1.address, courseId))
        .to.emit(course, EVENT_COURSE_COMPLETION_TRACKED);
    });
    
    it("Should update last completion timestamp", async function () {
      const courseId = "CS101";
      
      // Get initial course
      const initialCourse = await course.getCourseInfo(user1.address, courseId);
      
      // Wait a moment to ensure timestamp changes
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      // Increment completion count
      await course.connect(admin).incrementCompletionCount(user1.address, courseId);
      
      // Get updated course
      const updatedCourse = await course.getCourseInfo(user1.address, courseId);
      
      expect(updatedCourse.lastCompletionTimestamp).to.be.greaterThan(initialCourse.lastCompletionTimestamp);
    });
    
    it("Should not allow non-admin to increment completion count", async function () {
      const courseId = "CS101";
      
      // User2 is not admin
      await expect(
        course.connect(user2).incrementCompletionCount(user1.address, courseId)
      ).to.be.reverted;
    });
    
    it("Should not allow incrementing for non-existent course", async function () {
      const nonExistentCourseId = "FAKE101";
      
      await expect(
        course.connect(admin).incrementCompletionCount(user1.address, nonExistentCourseId)
      ).to.be.revertedWith("EducCourse: Course not found");
    });
  });

  describe("Course Querying", function () {
    beforeEach(async function () {
      // Create multiple courses
      await course.connect(user1)["createCourse(string,string,uint256,bytes32)"](
        "CS101",
        "Introduction to Computer Science",
        ethers.parseEther("50"),
        ethers.keccak256(ethers.toUtf8Bytes("metadata1"))
      );
      
      await course.connect(user1)["createCourse(string,string,uint256,bytes32)"](
        "CS201",
        "Data Structures",
        ethers.parseEther("75"),
        ethers.keccak256(ethers.toUtf8Bytes("metadata2"))
      );
      
      // Register user2 as educator and create a course
      await educator.connect(admin)["registerEducator(address,uint256)"](user2.address, ethers.parseEther("5000"));
      await course.grantRole(EDUCATOR_ROLE, user2.address);
      await course.connect(user2)["createCourse(string,string,uint256,bytes32)"](
        "MATH101",
        "Calculus I",
        ethers.parseEther("60"),
        ethers.keccak256(ethers.toUtf8Bytes("metadata3"))
      );
    });
    
    it("Should return correct course information", async function () {
      const courseInfo = await course.getCourseInfo(user1.address, "CS101");
      
      expect(courseInfo.courseId).to.equal("CS101");
      expect(courseInfo.courseName).to.equal("Introduction to Computer Science");
      expect(courseInfo.educator).to.equal(user1.address);
      expect(courseInfo.rewardAmount).to.equal(ethers.parseEther("50"));
      expect(courseInfo.completionCount).to.equal(0);
      expect(courseInfo.isActive).to.equal(true);
      expect(courseInfo.version).to.equal(1);
    });
    
    it("Should return legacy course information", async function () {
      const [
        courseId,
        courseName,
        educator,
        rewardAmount,
        completionCount,
        isActive,
        metadataHash,   
        createdAt, 
        lastUpdatedAt, 
        version
      ] = await course.getCourse(user1.address, "CS101");
      
      expect(courseId).to.equal("CS101");
      expect(courseName).to.equal("Introduction to Computer Science");
      expect(educator).to.equal(user1.address);
      expect(rewardAmount).to.equal(ethers.parseEther("50"));
      expect(completionCount).to.equal(0);
      expect(isActive).to.equal(true);
      expect(version).to.equal(1);
      expect(metadataHash).to.equal(ethers.keccak256(ethers.toUtf8Bytes("metadata1")));
      expect(createdAt).to.be.a('bigint').and.to.be.greaterThan(0); // Verificar que é um timestamp válido
      expect(lastUpdatedAt).to.equal(createdAt);
    });
    
    it("Should correctly identify active courses", async function () {
      expect(await course.isCourseActive(user1.address, "CS101")).to.equal(true);
      
      // Deactivate a course
      await course.connect(user1)["updateCourse(string,string,uint256,bool,bytes32,string)"](
        "CS101",
        "CS101", // Keep same name
        0, // Keep same reward
        false, // Set to inactive
        ethers.ZeroHash, // Keep same metadata
        "Deactivating course"
      );
      
      expect(await course.isCourseActive(user1.address, "CS101")).to.equal(false);
    });
    
    it("Should return correct course reward", async function () {
      const reward = await course.getCourseReward(user1.address, "CS101");
      expect(reward).to.equal(ethers.parseEther("50"));
    });
    
    it("Should return correct total courses count", async function () {
      const totalCourses = await course.getTotalCourses();
      expect(totalCourses).to.equal(3);
    });
    
    it("Should revert when querying non-existent course", async function () {
      await expect(
        course.getCourseInfo(user1.address, "NONEXISTENT")
      ).to.be.revertedWith("EducCourse: Course not found");
    });
  });
  
  describe("Pausing", function () {
    it("Should allow admin to pause the contract", async function () {
      await course.connect(admin).pause();
      expect(await course.paused()).to.equal(true);
    });

    it("Should allow admin to unpause the contract", async function () {
      await course.connect(admin).pause();
      await course.connect(admin).unpause();
      expect(await course.paused()).to.equal(false);
    });
    
    it("Should prevent course creation when paused", async function () {
      await course.connect(admin).pause();
      
      await expect(
        course.connect(user1)["createCourse(string,string,uint256,bytes32)"](
          "CS101",
          "Introduction to Computer Science",
          ethers.parseEther("50"),
          ethers.keccak256(ethers.toUtf8Bytes("metadata"))
        )
      ).to.be.reverted;
    });
    
    it("Should prevent course updates when paused", async function () {
      // Create a course
      await course.connect(user1)["createCourse(string,string,uint256,bytes32)"](
        "CS101",
        "Introduction to Computer Science",
        ethers.parseEther("50"),
        ethers.keccak256(ethers.toUtf8Bytes("metadata"))
      );
      
      // Pause the contract
      await course.connect(admin).pause();
      
      // Try to update course
      await expect(
        course.connect(user1)["updateCourse(string,string,uint256,bool,bytes32,string)"](
          "CS101",
          "Updated Course",
          ethers.parseEther("60"),
          true,
          ethers.ZeroHash,
          "Update attempt while paused"
        )
      ).to.be.reverted;
    });
  });
});