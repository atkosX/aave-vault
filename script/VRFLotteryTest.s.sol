// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {MultiTokenVault} from "../src/MultiTokenVault.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract VRFLotteryTest is Script, Test {
    address constant VAULT_ADDRESS = 0x00a9a7162107C8119b03C0ce2C9a2FF7bEd70C98;
    
    address alice = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // Account 1
    address bob = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;   // Account 2
    address charlie = 0x90F79bf6EB2c4f870365E785982E1f101E93b906; // Account 3
    address david = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65; // Account 4
    address eve = 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc;   // Account 5

    function run() external {
        console.log("=== VRF LOTTERY TEST ===");
        
        // Get vault instance
        MultiTokenVault vault = MultiTokenVault(payable(VAULT_ADDRESS));
        
        // Fund all participants with DAI and USDC
        deal(0x6B175474E89094C44Da98b954EedeAC495271d0F, alice, 2000e18); // 2000 DAI
        deal(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, alice, 2000e6);  // 2000 USDC
        deal(0x6B175474E89094C44Da98b954EedeAC495271d0F, bob, 2000e18);
        deal(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, bob, 2000e6);
        deal(0x6B175474E89094C44Da98b954EedeAC495271d0F, charlie, 2000e18);
        deal(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, charlie, 2000e6);
        deal(0x6B175474E89094C44Da98b954EedeAC495271d0F, david, 2000e18);
        deal(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, david, 2000e6);
        deal(0x6B175474E89094C44Da98b954EedeAC495271d0F, eve, 2000e18);
        deal(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, eve, 2000e6);
        
        console.log("All participants funded with 2000 DAI and 2000 USDC each");
        
        // All participants deposit to become eligible for lottery
        address[] memory participants = new address[](5);
        participants[0] = alice;
        participants[1] = bob;
        participants[2] = charlie;
        participants[3] = david;
        participants[4] = eve;
        
        console.log("\n=== PARTICIPANTS DEPOSITING ===");
        for (uint i = 0; i < participants.length; i++) {
            vm.startPrank(participants[i]);
            IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F).approve(address(vault), 1000e18);
            uint256 shares = vault.depositMulti(0x6B175474E89094C44Da98b954EedeAC495271d0F, 1000e18, participants[i]);
            vm.stopPrank();
            console.log("Participant", i+1, "deposited 1000 DAI, received shares:", shares / 1e18);
        }
        
        // Check participants are tracked
        address[] memory trackedParticipants = vault.getParticipants();
        console.log("\nTotal tracked participants:", trackedParticipants.length);
        
        for (uint i = 0; i < trackedParticipants.length; i++) {
            console.log("Participant", i+1);
            console.log("  Address:", trackedParticipants[i]);
            console.log("  Is participant:", vault.isParticipant(trackedParticipants[i]));
            console.log("  Shares:", vault.balanceOf(trackedParticipants[i]) / 1e18);
        }
        
        // Fund vault for yield simulation
        deal(0x6B175474E89094C44Da98b954EedeAC495271d0F, VAULT_ADDRESS, 500e18);
        deal(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, VAULT_ADDRESS, 250e6);
        
        // Simulate yield
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startPrank(deployer);
        vault.simulateYield(500e18, 0x6B175474E89094C44Da98b954EedeAC495271d0F);
        vault.simulateYield(250e6, 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        vm.stopPrank();
        
        console.log("\n=== YIELD SIMULATED ===");
        console.log("Vault total value USD:", vault.getTotalValueUSD() / 1e18);
        console.log("Vault share value USD:", vault.getShareValueUSD() / 1e18);
        
        // Fund vault with ETH for VRF
        deal(VAULT_ADDRESS, 2 ether);
        
        // Request VRF random yield distribution
        console.log("\n=== REQUESTING VRF LOTTERY ===");
        console.log("Total yield to distribute: 100 USDC");
        console.log("Number of winners: 3");
        console.log("Asset: USDC");
        
        vm.startPrank(deployer);
        uint256 requestId = vault.requestRandomYieldDistribution(
            100e6, // 100 USDC total yield
            3,    // 3 winners out of 5 participants
            0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, // USDC
            true  // Pay with native ETH
        );
        vm.stopPrank();
        
        console.log("VRF request submitted! Request ID:", requestId);
        
        // Check request details
        (uint256 totalYield, uint256 winnerCount, address toAsset, bool fulfilled) = 
            vault.getYieldDistributionRequestStatus(requestId);
        
        console.log("\nVRF Request Details:");
        console.log("- Request ID:", requestId);
        console.log("- Total yield:", totalYield / 1e6, "USDC");
        console.log("- Winner count:", winnerCount);
        console.log("- Asset:", toAsset);
        console.log("- Fulfilled:", fulfilled);
        
        // Simulate the random number and winner selection
        console.log("\n=== SIMULATING WINNER SELECTION ===");
        uint256 simulatedRandomNumber = 123456789012345678901234567890;
        console.log("Simulated random number:", simulatedRandomNumber);
        
        // Show how winners would be selected
        address[] memory currentParticipants = vault.getParticipants();
        console.log("\nAvailable participants for lottery:");
        for (uint256 i = 0; i < currentParticipants.length; i++) {
            console.log("  Participant", i+1);
            console.log("    Address:", currentParticipants[i]);
            console.log("    Shares:", vault.balanceOf(currentParticipants[i]) / 1e18);
        }
        
        // Simulate Fisher-Yates shuffle winner selection
        console.log("\nSimulating winner selection process:");
        address[] memory simParticipants = new address[](currentParticipants.length);
        for (uint256 i = 0; i < currentParticipants.length; i++) {
            simParticipants[i] = currentParticipants[i];
        }
        
        uint256 remainingCount = currentParticipants.length;
        uint256 simRandomSeed = simulatedRandomNumber;
        
        console.log("\nSelected winners:");
        for (uint256 i = 0; i < winnerCount; i++) {
            uint256 randomIndex = simRandomSeed % remainingCount;
            address winner = simParticipants[randomIndex];
            
            console.log("  Winner", i+1);
            console.log("    Address:", winner);
            console.log("    Selected at index:", randomIndex);
            console.log("    Shares:", vault.balanceOf(winner) / 1e18);
            
            // Move last element to selected position
            simParticipants[randomIndex] = simParticipants[remainingCount - 1];
            remainingCount--;
            
            // Generate next random seed
            simRandomSeed = uint256(keccak256(abi.encodePacked(simRandomSeed)));
        }
        
        console.log("\n=== LOTTERY SIMULATION COMPLETE ===");
        console.log("In a real environment:");
        console.log("- Chainlink VRF would provide cryptographically secure randomness");
        console.log("- The fulfillRandomWords callback would automatically execute");
        console.log("- 3 random winners would be selected from the 5 participants");
        console.log("- Each winner would receive 33.33 USDC (100 USDC / 3 winners)");
        console.log("- The yield would be distributed directly to winner addresses");
        
        console.log("\nVRF Lottery test completed successfully!");
    }
}
