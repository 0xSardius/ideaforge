// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/IdeaForge.sol";

contract IdeaForgeTest is Test {
    IdeaForge public ideaForge;

    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);

    // Mock Chainlink router for testing
    address public mockRouter = address(0x4);
    bytes32 public mockDonId = keccak256("test_don");
    uint64 public mockSubscriptionId = 1;

    string[] public sampleIdeas;

    event IdeasSubmitted(address indexed user, uint256[] ideaIds);
    event TokensRewarded(address indexed user, uint256 amount);
    event AIScoreUpdated(uint256 indexed ideaId, uint256 score, string category);

    function setUp() public {
        vm.prank(owner);
        ideaForge = new IdeaForge(mockRouter, mockDonId, mockSubscriptionId);

        // Setup sample ideas
        sampleIdeas = [
            "AI-powered meal planning app",
            "Blockchain voting system for schools",
            "Smart contract insurance for beginners",
            "VR therapy for anxiety treatment",
            "Automated garden watering system",
            "Peer-to-peer skill exchange platform",
            "Solar panel efficiency tracker",
            "Community-owned renewable energy grid",
            "Gamified language learning with NFTs",
            "Decentralized freelancer reputation system"
        ];
    }

    function testInitialState() public {
        assertEq(ideaForge.name(), "IdeaForge Token");
        assertEq(ideaForge.symbol(), "IDEA");
        assertEq(ideaForge.ideaCounter(), 0);
        assertEq(ideaForge.DAILY_REWARD(), 10 * 10 ** 18);
        assertEq(ideaForge.IDEAS_PER_DAY(), 10);
    }

    function testSubmitDailyIdeas() public {
        vm.startPrank(user1);

        // Test successful submission
        vm.expectEmit(true, false, false, false);
        emit IdeasSubmitted(user1, new uint256[](10));

        ideaForge.submitDailyIdeas(sampleIdeas);

        // Check user stats updated
        (uint256 currentStreak, uint256 longestStreak, uint256 totalIdeas,, uint256 lastSubmission,) =
            ideaForge.users(user1);

        assertEq(currentStreak, 1);
        assertEq(longestStreak, 1);
        assertEq(totalIdeas, 10);
        assertEq(lastSubmission, block.timestamp);

        // Check ideas were stored
        for (uint256 i = 1; i <= 10; i++) {
            (string memory content, address creator, uint256 timestamp,,,, bool isPublic,) = ideaForge.ideas(i);
            assertEq(content, sampleIdeas[i - 1]);
            assertEq(creator, user1);
            assertEq(timestamp, block.timestamp);
            assertTrue(isPublic);
        }

        vm.stopPrank();
    }

    function testCannotSubmitTwiceInOneDay() public {
        vm.startPrank(user1);

        // First submission should succeed
        ideaForge.submitDailyIdeas(sampleIdeas);

        // Second submission should fail
        vm.expectRevert("Already submitted today");
        ideaForge.submitDailyIdeas(sampleIdeas);

        vm.stopPrank();
    }

    function testInvalidIdeaCount() public {
        string[] memory shortIdeas = new string[](5);
        for (uint256 i = 0; i < 5; i++) {
            shortIdeas[i] = "Test idea";
        }

        vm.prank(user1);
        vm.expectRevert("Must submit exactly 10 ideas");
        ideaForge.submitDailyIdeas(shortIdeas);
    }

    function testInvalidIdeaLength() public {
        string[] memory invalidIdeas = sampleIdeas;
        invalidIdeas[0] = ""; // Empty idea

        vm.prank(user1);
        vm.expectRevert("Invalid idea length");
        ideaForge.submitDailyIdeas(invalidIdeas);

        // Test too long idea
        invalidIdeas[0] =
            "This idea is way too long and exceeds the maximum character limit of 200 characters. It should fail validation and not be accepted by the smart contract. We need to make sure our validation works properly for edge cases like this one.";

        vm.prank(user1);
        vm.expectRevert("Invalid idea length");
        ideaForge.submitDailyIdeas(invalidIdeas);
    }

    function testStreakCalculation() public {
        vm.startPrank(user1);

        // Day 1
        ideaForge.submitDailyIdeas(sampleIdeas);
        (uint256 currentStreak1, uint256 longestStreak1,,,,) = ideaForge.users(user1);
        assertEq(currentStreak1, 1);
        assertEq(longestStreak1, 1);

        // Day 2 (next day)
        vm.warp(block.timestamp + 1 days);
        ideaForge.submitDailyIdeas(sampleIdeas);
        (uint256 currentStreak2, uint256 longestStreak2,,,,) = ideaForge.users(user1);
        assertEq(currentStreak2, 2);
        assertEq(longestStreak2, 2);

        // Day 5 (skip day 3 and 4, streak should reset)
        vm.warp(block.timestamp + 3 days);
        ideaForge.submitDailyIdeas(sampleIdeas);
        (uint256 currentStreak3, uint256 longestStreak3,,,,) = ideaForge.users(user1);
        assertEq(currentStreak3, 1); // Reset to 1
        assertEq(longestStreak3, 2); // Longest streak preserved

        vm.stopPrank();
    }

    function testHasSubmittedToday() public {
        vm.startPrank(user1);

        assertFalse(ideaForge.hasSubmittedToday(user1));

        ideaForge.submitDailyIdeas(sampleIdeas);
        assertTrue(ideaForge.hasSubmittedToday(user1));

        // Next day
        vm.warp(block.timestamp + 1 days);
        assertFalse(ideaForge.hasSubmittedToday(user1));

        vm.stopPrank();
    }

    function testMultipleUsers() public {
        // User 1 submits
        vm.prank(user1);
        ideaForge.submitDailyIdeas(sampleIdeas);

        // User 2 submits
        vm.prank(user2);
        ideaForge.submitDailyIdeas(sampleIdeas);

        // Check both users have correct stats
        (uint256 streak1,, uint256 total1,,,) = ideaForge.users(user1);
        (uint256 streak2,, uint256 total2,,,) = ideaForge.users(user2);

        assertEq(streak1, 1);
        assertEq(streak2, 1);
        assertEq(total1, 10);
        assertEq(total2, 10);

        // Check idea counter is correct
        assertEq(ideaForge.ideaCounter(), 20);
    }

    function testOwnerFunctions() public {
        string memory newSource = "new AI source code";
        uint64 newSubId = 999;

        // Non-owner should fail
        vm.prank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        ideaForge.setAISource(newSource);

        vm.prank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        ideaForge.setSubscriptionId(newSubId);

        // Owner should succeed
        vm.startPrank(owner);
        ideaForge.setAISource(newSource);
        ideaForge.setSubscriptionId(newSubId);
        vm.stopPrank();

        assertEq(ideaForge.aiAnalysisSource(), newSource);
        assertEq(ideaForge.subscriptionId(), newSubId);
    }

    function testFuzzIdeaSubmission(uint8 ideaCount) public {
        vm.assume(ideaCount != 10); // Assume not exactly 10

        string[] memory ideas = new string[](ideaCount);
        for (uint256 i = 0; i < ideaCount; i++) {
            ideas[i] = "Test idea";
        }

        vm.prank(user1);
        vm.expectRevert("Must submit exactly 10 ideas");
        ideaForge.submitDailyIdeas(ideas);
    }

    function testFuzzStreakCalculation(uint256 dayGap) public {
        vm.assume(dayGap > 0 && dayGap < 365); // Reasonable bounds

        vm.startPrank(user1);

        // First submission
        ideaForge.submitDailyIdeas(sampleIdeas);

        // Wait and submit again
        vm.warp(block.timestamp + (dayGap * 1 days));
        ideaForge.submitDailyIdeas(sampleIdeas);

        (uint256 currentStreak,,,,,) = ideaForge.users(user1);

        if (dayGap == 1) {
            assertEq(currentStreak, 2); // Consecutive day
        } else {
            assertEq(currentStreak, 1); // Streak reset
        }

        vm.stopPrank();
    }
}
