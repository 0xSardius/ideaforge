// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/IdeaForge.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("========================================");
        console.log("DEPLOYING IDEAFORGE TO BASE SEPOLIA");
        console.log("========================================");
        console.log("Deployer address:", deployer);
        console.log("Deployer balance:", deployer.balance / 1e18, "ETH");
        
        // Base Sepolia Chainlink configuration
        address router = 0xA9d587a00A31A52Ed70D6026794a8FC5E2F5dCb0; // Base Sepolia Functions Router
        bytes32 donId = 0x66756e2d626173652d7365706f6c69612d310000000000000000000000000000; // Base Sepolia DON ID
        uint64 subscriptionId = vm.envUint("CHAINLINK_SUBSCRIPTION_ID");
        
        console.log("Chainlink Router:", router);
        console.log("DON ID:", vm.toString(donId));
        console.log("Subscription ID:", subscriptionId);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy the contract
        IdeaForge ideaForge = new IdeaForge(router, donId, subscriptionId);
        
        console.log("========================================");
        console.log("DEPLOYMENT SUCCESSFUL!");
        console.log("========================================");
        console.log("Contract address:", address(ideaForge));
        console.log("Contract owner:", ideaForge.owner());
        console.log("Token name:", ideaForge.name());
        console.log("Token symbol:", ideaForge.symbol());
        console.log("Daily reward:", ideaForge.DAILY_REWARD() / 1e18, "IDEA");
        console.log("Ideas per day:", ideaForge.IDEAS_PER_DAY());
        
        vm.stopBroadcast();
        
        // Save deployment info
        string memory deploymentInfo = string(abi.encodePacked(
            "IDEAFORGE_CONTRACT_ADDRESS=", vm.toString(address(ideaForge)), "\n",
            "IDEAFORGE_OWNER=", vm.toString(ideaForge.owner()), "\n",
            "DEPLOYMENT_BLOCK=", vm.toString(block.number), "\n",
            "DEPLOYMENT_TIMESTAMP=", vm.toString(block.timestamp)
        ));
        
        vm.writeFile("./deployment.env", deploymentInfo);
        console.log("Deployment info saved to deployment.env");
        
        console.log("========================================");
        console.log("NEXT STEPS:");
        console.log("1. Verify contract: forge verify-contract", vm.toString(address(ideaForge)), "src/IdeaForge.sol:IdeaForge --chain base-sepolia");
        console.log("2. Fund Chainlink subscription with LINK tokens");
        console.log("3. Add contract as consumer to Chainlink subscription");
        console.log("4. Set AI source code with setAISource()");
        console.log("========================================");
    }
}