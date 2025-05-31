// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/IdeaForge.sol";

contract ChainlinkMockTest is Test {
    IdeaForge public ideaForge;

    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public mockRouter = address(0x4);
    bytes32 public mockDonId = keccak256("test_don");
    uint64 public mockSubscriptionId = 1;

    string[] public sampleIdeas;

    function setUp() public {
        vm.prank(owner);
        ideaForge = new IdeaForge(mockRouter, mockDonId, mockSubscriptionId);

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

    function testAIAnalysisCallback() public {
        vm.startPrank(user1);

        // Submit ideas to trigger AI analysis
        ideaForge.submitDailyIdeas(sampleIdeas);

        // Check that tokens haven't been minted yet (waiting for AI analysis)
        assertEq(ideaForge.balanceOf(user1), 0);

        vm.stopPrank();

        // Simulate Chainlink Functions callback
        bytes32 mockRequestId = keccak256("mock_request");
        bytes memory mockResponse = abi.encode("mock AI analysis response");

        // Mock the callback (this would normally come from Chainlink router)
        vm.prank(mockRouter);
        // Note: We'd need to make fulfillRequest public or create a test version
        // For now, this demonstrates the test structure
    }

    function testAIScoreProcessing() public {
        vm.prank(user1);
        ideaForge.submitDailyIdeas(sampleIdeas);

        // Check initial states
        for (uint256 i = 1; i <= 10; i++) {
            (,,, uint256 aiScore,,,, bool isAnalyzed) = ideaForge.ideas(i);
            assertEq(aiScore, 0);
            assertFalse(isAnalyzed);
        }

        // After processing (we'd simulate the callback here)
        // Ideas should have scores and be marked as analyzed
    }
}
