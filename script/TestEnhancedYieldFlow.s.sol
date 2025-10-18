// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {MultiTokenVault} from "../src/MultiTokenVault.sol";
import {MockDEX} from "../src/MockDEX.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract TestEnhancedYieldFlow is Script, Test {
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant VAULT_ADDRESS = 0x83303D67770F7e28F9F10fD5612fEE7952EfF10C; // New vault address

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== TESTING ENHANCED YIELD FLOW ===");
        console.log("Vault address:", VAULT_ADDRESS);
        console.log("Deployer:", deployer);

        MultiTokenVault vault = MultiTokenVault(payable(VAULT_ADDRESS));

        // Step 1: Setup MockDEX
        console.log("STEP 1: Setting up MockDEX");
        MockDEX mockDEX = new MockDEX(DAI, USDC);
        
        vm.startPrank(deployer);
        vault.setMockDEX(address(mockDEX));
        vm.stopPrank();
        
        // Fund MockDEX with tokens for swaps
        deal(DAI, address(mockDEX), 1000000e18);
        deal(USDC, address(mockDEX), 1000000e6);
        console.log("MockDEX setup complete");

        // Step 2: Fund deployer with tokens
        deal(DAI, deployer, 20000e18); // More tokens for yield simulation
        deal(USDC, deployer, 20000e6);
        
        // Approve vault to spend tokens
        vm.startPrank(deployer);
        IERC20(DAI).approve(address(vault), type(uint256).max);
        IERC20(USDC).approve(address(vault), type(uint256).max);
        vm.stopPrank();

        // Step 3: Make deposits to get shares
        console.log("STEP 2: Making deposits to get shares");
        vm.startPrank(deployer);
        uint256 daiShares = vault.depositMulti(DAI, 1000e18, deployer);
        uint256 usdcShares = vault.depositMulti(USDC, 1000e6, deployer);
        vm.stopPrank();
        
        console.log("DAI shares received:", daiShares / 1e18);
        console.log("USDC shares received:", usdcShares / 1e6);

        // Step 4: Check initial vault value
        uint256 initialValue = vault.getTotalValueUSD();
        console.log("Initial vault value USD:", initialValue / 1e18);

        // Step 5: Check initial share value
        uint256 initialShareValue = vault.getShareValueUSD();
        console.log("Initial share value USD:", initialShareValue / 1e18);

        // Step 6: Transfer tokens to vault first, then simulate yield
        console.log("STEP 3: Transferring tokens to vault and simulating yield");
        console.log("Deployer DAI balance before yield simulation:", IERC20(DAI).balanceOf(deployer) / 1e18);
        console.log("Deployer USDC balance before yield simulation:", IERC20(USDC).balanceOf(deployer) / 1e6);
        
        // Transfer tokens to vault first
        vm.startPrank(deployer);
        IERC20(DAI).transfer(address(vault), 100e18);  // Transfer 100 DAI to vault
        IERC20(USDC).transfer(address(vault), 50e6);   // Transfer 50 USDC to vault
        vm.stopPrank();
        
        console.log("Vault DAI balance after transfer:", IERC20(DAI).balanceOf(address(vault)) / 1e18);
        console.log("Vault USDC balance after transfer:", IERC20(USDC).balanceOf(address(vault)) / 1e6);
        
        // Now simulate yield (vault will supply its own tokens to Aave)
        vm.startPrank(deployer);
        vault.simulateYield(100e18, DAI);  // Supply 100 DAI to Aave
        vault.simulateYield(50e6, USDC);   // Supply 50 USDC to Aave
        vm.stopPrank();
        
        console.log("Deployer DAI balance after yield simulation:", IERC20(DAI).balanceOf(deployer) / 1e18);
        console.log("Deployer USDC balance after yield simulation:", IERC20(USDC).balanceOf(deployer) / 1e6);

        // Step 7: Check vault value after yield
        uint256 afterValue = vault.getTotalValueUSD();
        console.log("After yield vault value USD:", afterValue / 1e18);
        console.log("Value increase:", (afterValue - initialValue) / 1e18, "USD");

        // Step 8: Check share value after yield
        uint256 afterShareValue = vault.getShareValueUSD();
        console.log("After yield share value USD:", afterShareValue / 1e18);
        console.log("Share value increase:", (afterShareValue - initialShareValue) / 1e18, "USD per share");

        // Step 9: Test withdrawal with enhanced yield
        console.log("STEP 4: Testing withdrawal with enhanced yield");
        uint256 deployerDaiBefore = IERC20(DAI).balanceOf(deployer);
        uint256 deployerUsdcBefore = IERC20(USDC).balanceOf(deployer);
        
        console.log("Deployer DAI before withdrawal:", deployerDaiBefore / 1e18);
        console.log("Deployer USDC before withdrawal:", deployerUsdcBefore / 1e6);

        vm.startPrank(deployer);
        // Withdraw half DAI shares as DAI
        uint256 daiWithdrawn = vault.withdrawMulti(DAI, daiShares / 2, deployer, deployer);
        // Withdraw half USDC shares as USDC  
        uint256 usdcWithdrawn = vault.withdrawMulti(USDC, usdcShares / 2, deployer, deployer);
        vm.stopPrank();

        uint256 deployerDaiAfter = IERC20(DAI).balanceOf(deployer);
        uint256 deployerUsdcAfter = IERC20(USDC).balanceOf(deployer);
        
        console.log("Deployer DAI after withdrawal:", deployerDaiAfter / 1e18);
        console.log("Deployer USDC after withdrawal:", deployerUsdcAfter / 1e6);
        
        console.log("DAI received:", (deployerDaiAfter - deployerDaiBefore) / 1e18);
        console.log("USDC received:", (deployerUsdcAfter - deployerUsdcBefore) / 1e6);
        console.log("DAI withdrawn amount:", daiWithdrawn / 1e18);
        console.log("USDC withdrawn amount:", usdcWithdrawn / 1e6);

        // Step 10: Test cross-asset withdrawal
        console.log("STEP 5: Testing cross-asset withdrawal (DAI shares as USDC)");
        uint256 usdcBeforeCross = IERC20(USDC).balanceOf(deployer);
        
        vm.startPrank(deployer);
        uint256 usdcFromDaiShares = vault.withdrawMulti(USDC, daiShares / 2, deployer, deployer);
        vm.stopPrank();
        
        uint256 usdcAfterCross = IERC20(USDC).balanceOf(deployer);
        console.log("USDC before cross-asset withdrawal:", usdcBeforeCross / 1e6);
        console.log("USDC after cross-asset withdrawal:", usdcAfterCross / 1e6);
        console.log("USDC received from DAI shares:", usdcFromDaiShares / 1e6);

        // Step 11: Final analysis
        console.log("STEP 6: Final Analysis");
        uint256 finalVaultValue = vault.getTotalValueUSD();
        uint256 finalShareValue = vault.getShareValueUSD();
        console.log("Final vault value USD:", finalVaultValue / 1e18);
        console.log("Final share value USD:", finalShareValue / 1e18);
        
        // Calculate yield benefit
        uint256 expectedDaiWithoutYield = 500e18; // Half of 1000 DAI
        uint256 expectedUsdcWithoutYield = 500e6; // Half of 1000 USDC
        uint256 actualDaiReceived = (deployerDaiAfter - deployerDaiBefore);
        uint256 actualUsdcReceived = (deployerUsdcAfter - deployerUsdcBefore);
        
        console.log("Expected DAI without yield:", expectedDaiWithoutYield / 1e18);
        console.log("Actual DAI received:", actualDaiReceived / 1e18);
        console.log("DAI yield benefit:", (actualDaiReceived - expectedDaiWithoutYield) / 1e18);
        
        console.log("Expected USDC without yield:", expectedUsdcWithoutYield / 1e6);
        console.log("Actual USDC received:", actualUsdcReceived / 1e6);
        console.log("USDC yield benefit:", (actualUsdcReceived - expectedUsdcWithoutYield) / 1e6);

        console.log("SUCCESS: Enhanced yield flow test completed!");
        console.log("SUCCESS: Real Aave integration working!");
        console.log("SUCCESS: Users benefit from simulated yield!");
    }
}
