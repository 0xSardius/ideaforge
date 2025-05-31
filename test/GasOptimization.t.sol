// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/IdeaForge.sol";

contract GasOptimizationTest is Test {
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

    function testGasUsageSubmitIdeas() public {
        vm.prank(user1);

        uint256 gasBefore = gasleft();
        ideaForge.submitDailyIdeas(sampleIdeas);
        uint256 gasUsed = gasBefore - gasleft();

        console.log("Gas used for submitting 10 ideas:", gasUsed);

        // Assert reasonable gas usage (adjust based on actual measurements)
        assertLt(gasUsed, 500000, "Gas usage too high for idea submission");
    }

    function testGasUsageStreakUpdate() public {
        vm.startPrank(user1);

        // First submission
        ideaForge.submitDailyIdeas(sampleIdeas);

        // Next day submission
        vm.warp(block.timestamp + 1 days);

        uint256 gasBefore = gasleft();
        ideaForge.submitDailyIdeas(sampleIdeas);
        uint256 gasUsed = gasBefore - gasleft();

        console.log("Gas used for streak update:", gasUsed);

        vm.stopPrank();
    }
}
