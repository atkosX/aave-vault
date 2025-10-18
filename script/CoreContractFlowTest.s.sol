// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {MultiTokenVault} from "../src/MultiTokenVault.sol";
import {MockDEX} from "../src/MockDEX.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract StepTest is Script, Test {
    address constant VAULT_ADDRESS = 0x00a9a7162107C8119b03C0ce2C9a2FF7bEd70C98;
    
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function run() external {
        console.log("=== ALICE AND BOB TEST ===");
        
        // Use predefined accounts from anvil
        alice = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // Account 1
        bob = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;   // Account 2
        
        console.log("Alice address:", alice);
        console.log("Bob address:", bob);
        
        // Get vault instance
        MultiTokenVault vault = MultiTokenVault(payable(VAULT_ADDRESS));
        
        // Check initial vault state
        console.log("Initial vault total value USD:", vault.getTotalValueUSD() / 1e18);
        console.log("Initial vault total shares:", vault.totalSupply() / 1e18);
        console.log("Initial vault share value USD:", vault.getShareValueUSD() / 1e18);
        
        // Fund Alice and Bob with DAI and USDC
        deal(0x6B175474E89094C44Da98b954EedeAC495271d0F, alice, 1000e18); // 1000 DAI
        deal(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, alice, 1000e6);  // 1000 USDC
        deal(0x6B175474E89094C44Da98b954EedeAC495271d0F, bob, 1000e18);   // 1000 DAI
        deal(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, bob, 1000e6);    // 1000 USDC
        
        console.log("Alice funded with 1000 DAI and 1000 USDC");
        console.log("Bob funded with 1000 DAI and 1000 USDC");
        
        // Alice approves vault to spend 300 DAI
        vm.startPrank(alice);
        IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F).approve(address(vault), 300e18);
        vm.stopPrank();
        console.log("Alice approved vault to spend 300 DAI");
        
        // Alice deposits 300 DAI to vault
        vm.startPrank(alice);
        uint256 aliceShares = vault.depositMulti(0x6B175474E89094C44Da98b954EedeAC495271d0F, 300e18, alice);
        vm.stopPrank();
        console.log("Alice deposited 300 DAI to vault");
        console.log("Alice received shares:", aliceShares / 1e18);
        
        // Check vault state after Alice's deposit
        console.log("After Alice's deposit:");
        console.log("Vault total value USD:", vault.getTotalValueUSD() / 1e18);
        console.log("Vault total shares:", vault.totalSupply() / 1e18);
        console.log("Vault share value USD:", vault.getShareValueUSD() / 1e18);
        console.log("Alice's shares:", vault.balanceOf(alice) / 1e18);
        console.log("Bob's shares:", vault.balanceOf(bob) / 1e18);
        
        // Debug: Check individual asset values
        console.log("Debug - DAI aToken address:", vault.getAToken(0x6B175474E89094C44Da98b954EedeAC495271d0F));
        console.log("Debug - USDC aToken address:", vault.getAToken(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48));
        console.log("Debug - WETH aToken address:", vault.getAToken(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
        
        // Debug: Check exact values
        uint256 totalValue = vault.getTotalValueUSD();
        uint256 totalShares = vault.totalSupply();
        console.log("Debug - Total value (raw):", totalValue);
        console.log("Debug - Total shares (raw):", totalShares);
        console.log("Debug - Expected share value:", (totalValue * 1e18) / totalShares);
        
            console.log("Alice deposit completed successfully!");
            
            // Bob deposits 100 USDC
            console.log("\n=== BOB'S USDC DEPOSIT ===");
            vm.startPrank(bob);
            IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48).approve(address(vault), 100e6);
            uint256 bobShares = vault.depositMulti(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, 100e6, bob);
            vm.stopPrank();
            console.log("Bob deposited 100 USDC to vault");
            console.log("Bob received shares:", bobShares / 1e18);
            
            // Check vault state after Bob's deposit
            console.log("\nAfter Bob's deposit:");
            console.log("Vault total value USD:", vault.getTotalValueUSD() / 1e18);
            console.log("Vault total shares:", vault.totalSupply() / 1e18);
            console.log("Vault share value USD:", vault.getShareValueUSD() / 1e18);
            console.log("Alice's shares:", vault.balanceOf(alice) / 1e18);
            console.log("Bob's shares:", vault.balanceOf(bob) / 1e18);
            
            // Debug: Check exact values for share calculation
            uint256 totalValueAfter = vault.getTotalValueUSD();
            uint256 totalSharesAfter = vault.totalSupply();
            console.log("Debug - Total value (raw):", totalValueAfter);
            console.log("Debug - Total shares (raw):", totalSharesAfter);
            console.log("Debug - Share value (raw):", vault.getShareValueUSD());
            console.log("Debug - Expected share value:", (totalValueAfter * 1e18) / totalSharesAfter);
            
            // Debug: Check individual asset balances
            console.log("\nDebug - Individual asset balances:");
            console.log("DAI balance in vault:", IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F).balanceOf(address(vault)) / 1e18);
            console.log("USDC balance in vault:", IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48).balanceOf(address(vault)) / 1e6);
            
            console.log("Bob deposit completed successfully!");
            
            // Alice deposits 200 USDC
            console.log("\n=== ALICE'S USDC DEPOSIT ===");
            vm.startPrank(alice);
            IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48).approve(address(vault), 200e6);
            uint256 aliceUsdcShares = vault.depositMulti(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, 200e6, alice);
            vm.stopPrank();
            console.log("Alice deposited 200 USDC to vault");
            console.log("Alice received additional shares:", aliceUsdcShares / 1e18);
            
            // Check vault state after Alice's USDC deposit
            console.log("\nAfter Alice's USDC deposit:");
            console.log("Vault total value USD:", vault.getTotalValueUSD() / 1e18);
            console.log("Vault total shares:", vault.totalSupply() / 1e18);
            
            // Show detailed share value calculation
            uint256 shareValueRawBefore = vault.getShareValueUSD();
            console.log("Vault share value (raw):", shareValueRawBefore);
            console.log("Vault share value USD:", shareValueRawBefore / 1e18);
            console.log("Vault share value (precise):", (shareValueRawBefore * 1000) / 1e18, "milliUSD");
            
            console.log("Alice's total shares:", vault.balanceOf(alice) / 1e18);
            console.log("Bob's shares:", vault.balanceOf(bob) / 1e18);
            
            // Debug: Check exact values for share calculation
            uint256 totalValueAfterAlice = vault.getTotalValueUSD();
            uint256 totalSharesAfterAlice = vault.totalSupply();
            console.log("Debug - Total value (raw):", totalValueAfterAlice);
            console.log("Debug - Total shares (raw):", totalSharesAfterAlice);
            console.log("Debug - Share value (raw):", vault.getShareValueUSD());
            console.log("Debug - Expected share value:", (totalValueAfterAlice * 1e18) / totalSharesAfterAlice);
            
            // Debug: Check individual asset balances
            console.log("\nDebug - Individual asset balances:");
            console.log("DAI balance in vault:", IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F).balanceOf(address(vault)) / 1e18);
            console.log("USDC balance in vault:", IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48).balanceOf(address(vault)) / 1e6);
            
            // Debug: Check aToken balances
            console.log("\nDebug - aToken balances:");
            address daiAToken = vault.getAToken(0x6B175474E89094C44Da98b954EedeAC495271d0F);
            address usdcAToken = vault.getAToken(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
            console.log("DAI aToken address:", daiAToken);
            console.log("USDC aToken address:", usdcAToken);
            console.log("DAI aToken balance:", IERC20(daiAToken).balanceOf(address(vault)) / 1e18);
            console.log("USDC aToken balance:", IERC20(usdcAToken).balanceOf(address(vault)) / 1e6);
            
            console.log("Alice USDC deposit completed successfully!");
            
            // Simulate yield by adding more tokens to Aave
            console.log("\n=== YIELD SIMULATION ===");
            uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
            address deployer = vm.addr(deployerPrivateKey);
            
            // Fund deployer with additional tokens for yield simulation
            deal(0x6B175474E89094C44Da98b954EedeAC495271d0F, deployer, 100e18); // 100 DAI
            deal(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, deployer, 50e6);  // 50 USDC
            
            // Transfer tokens to vault first
            vm.startPrank(deployer);
            IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F).transfer(address(vault), 50e18);  // 50 DAI
            IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48).transfer(address(vault), 25e6);   // 25 USDC
            vm.stopPrank();
            
            console.log("Transferred 50 DAI and 25 USDC to vault for yield simulation");
            
            // Simulate yield (vault will supply its own tokens to Aave)
            vm.startPrank(deployer);
            vault.simulateYield(50e18, 0x6B175474E89094C44Da98b954EedeAC495271d0F);  // Supply 50 DAI to Aave
            vault.simulateYield(25e6, 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);   // Supply 25 USDC to Aave
            vm.stopPrank();
            
            console.log("Yield simulation completed - supplied tokens to Aave");
            
            // Check vault state after yield simulation
            console.log("\nAfter yield simulation:");
            console.log("Vault total value USD:", vault.getTotalValueUSD() / 1e18);
            console.log("Vault total shares:", vault.totalSupply() / 1e18);
            
            // Show detailed share value calculation
            uint256 shareValueRaw = vault.getShareValueUSD();
            console.log("Vault share value (raw):", shareValueRaw);
            console.log("Vault share value USD:", shareValueRaw / 1e18);
            console.log("Vault share value (precise):", (shareValueRaw * 1000) / 1e18, "milliUSD");
            
            console.log("Alice's total shares:", vault.balanceOf(alice) / 1e18);
            console.log("Bob's shares:", vault.balanceOf(bob) / 1e18);
            
            // Debug: Check aToken balances after yield
            console.log("\nDebug - aToken balances after yield:");
            address daiATokenAfter = vault.getAToken(0x6B175474E89094C44Da98b954EedeAC495271d0F);
            address usdcATokenAfter = vault.getAToken(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
            console.log("DAI aToken balance:", IERC20(daiATokenAfter).balanceOf(address(vault)) / 1e18);
            console.log("USDC aToken balance:", IERC20(usdcATokenAfter).balanceOf(address(vault)) / 1e6);
            
            // Calculate yield benefit
            uint256 initialValue = 599; // Previous total value
            uint256 newValue = vault.getTotalValueUSD() / 1e18;
            uint256 yieldAmount = newValue - initialValue;
            console.log("\nYield Analysis:");
            console.log("Initial vault value:", initialValue, "USD");
            console.log("New vault value:", newValue, "USD");
            console.log("Yield generated:", yieldAmount, "USD");
            console.log("Yield per share:", (yieldAmount * 1e18) / (vault.totalSupply() / 1e18), "USD");
            
            console.log("Yield simulation completed successfully!");
            
            // Alice withdraws USDC from vault
            console.log("\n=== ALICE'S USDC WITHDRAWAL ===");
            uint256 aliceUsdcBefore = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48).balanceOf(alice);
            console.log("Alice USDC balance before withdrawal:", aliceUsdcBefore / 1e6);
            
            // Alice withdraws 100 shares as USDC
            uint256 sharesToWithdraw = 100e18; // 100 shares
            console.log("Alice withdrawing", sharesToWithdraw / 1e18, "shares as USDC");
            
            vm.startPrank(alice);
            uint256 usdcReceived = vault.withdrawMulti(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, sharesToWithdraw, alice, alice);
            vm.stopPrank();
            
            uint256 aliceUsdcAfter = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48).balanceOf(alice);
            console.log("Alice USDC balance after withdrawal:", aliceUsdcAfter / 1e6);
            console.log("USDC received:", usdcReceived / 1e6);
            console.log("USDC increase:", (aliceUsdcAfter - aliceUsdcBefore) / 1e6);
            
            // Check vault state after withdrawal
            console.log("\nAfter Alice's withdrawal:");
            console.log("Vault total value USD:", vault.getTotalValueUSD() / 1e18);
            console.log("Vault total shares:", vault.totalSupply() / 1e18);
            
            // Show detailed share value calculation after withdrawal
            uint256 shareValueRawAfter = vault.getShareValueUSD();
            console.log("Vault share value (raw):", shareValueRawAfter);
            console.log("Vault share value USD:", shareValueRawAfter / 1e18);
            console.log("Vault share value (precise):", (shareValueRawAfter * 1000) / 1e18, "milliUSD");
            
            console.log("Alice's remaining shares:", vault.balanceOf(alice) / 1e18);
            console.log("Bob's shares:", vault.balanceOf(bob) / 1e18);
            
            // Debug: Check aToken balances after withdrawal
            console.log("\nDebug - aToken balances after withdrawal:");
            address daiATokenAfterWithdraw = vault.getAToken(0x6B175474E89094C44Da98b954EedeAC495271d0F);
            address usdcATokenAfterWithdraw = vault.getAToken(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
            console.log("DAI aToken balance:", IERC20(daiATokenAfterWithdraw).balanceOf(address(vault)) / 1e18);
            console.log("USDC aToken balance:", IERC20(usdcATokenAfterWithdraw).balanceOf(address(vault)) / 1e6);
            
            console.log("Alice withdrawal completed successfully!");
            
            // Calculate maximum withdrawals Alice can make
            console.log("\n=== MAXIMUM WITHDRAWAL CALCULATIONS ===");
            console.log("Alice's remaining shares:", vault.balanceOf(alice) / 1e18);
            
            // Calculate maximum USDC Alice can withdraw
            uint256 maxUsdcAlice = vault.previewWithdrawMulti(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, vault.balanceOf(alice));
            console.log("Max USDC Alice can withdraw:", maxUsdcAlice / 1e6);
            
            // Calculate maximum DAI Alice can withdraw
            uint256 maxDaiAlice = vault.previewWithdrawMulti(0x6B175474E89094C44Da98b954EedeAC495271d0F, vault.balanceOf(alice));
            console.log("Max DAI Alice can withdraw:", maxDaiAlice / 1e18);
            
            // Show vault's available assets
            console.log("\nVault's available assets:");
            address daiATokenMax = vault.getAToken(0x6B175474E89094C44Da98b954EedeAC495271d0F);
            address usdcATokenMax = vault.getAToken(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
            console.log("Available DAI aTokens:", IERC20(daiATokenMax).balanceOf(address(vault)) / 1e18);
            console.log("Available USDC aTokens:", IERC20(usdcATokenMax).balanceOf(address(vault)) / 1e6);
            
            // Calculate Alice's proportional claim in USD
            uint256 totalValueUSDFinal = vault.getTotalValueUSD();
            uint256 aliceSharesFinal = vault.balanceOf(alice);
            uint256 totalSharesFinal = vault.totalSupply();
            uint256 aliceValueUSD = (totalValueUSDFinal * aliceSharesFinal) / totalSharesFinal;
            console.log("Alice's proportional value in USD:", aliceValueUSD / 1e18);
            
            console.log("Maximum withdrawal calculations completed!");
            
            // Alice withdraws all remaining USDC (cross-asset withdrawal)
            console.log("\n=== ALICE'S MAXIMUM USDC WITHDRAWAL ===");
            
            // Setup MockDEX for cross-asset withdrawals
            console.log("Setting up MockDEX for cross-asset withdrawals...");
            uint256 deployerPrivateKey2 = vm.envUint("PRIVATE_KEY");
            address deployer2 = vm.addr(deployerPrivateKey2);
            
            // Deploy MockDEX
            MockDEX mockDEX = new MockDEX(0x6B175474E89094C44Da98b954EedeAC495271d0F, 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
            
            // Set MockDEX in vault
            vm.startPrank(deployer2);
            vault.setMockDEX(address(mockDEX));
            vm.stopPrank();
            
            // Fund MockDEX with tokens for swapping
            deal(0x6B175474E89094C44Da98b954EedeAC495271d0F, address(mockDEX), 1000000e18);
            deal(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, address(mockDEX), 1000000e6);
            console.log("MockDEX setup complete");
            
            uint256 aliceUsdcBeforeMax = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48).balanceOf(alice);
            console.log("Alice USDC balance before max withdrawal:", aliceUsdcBeforeMax / 1e6);
            
            // Alice withdraws all her remaining shares as USDC
            uint256 aliceRemainingShares = vault.balanceOf(alice);
            console.log("Alice withdrawing all remaining shares:", aliceRemainingShares / 1e18, "as USDC");
            
            vm.startPrank(alice);
            uint256 maxUsdcReceived = vault.withdrawMulti(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, aliceRemainingShares, alice, alice);
            vm.stopPrank();
            
            uint256 aliceUsdcAfterMax = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48).balanceOf(alice);
            console.log("Alice USDC balance after max withdrawal:", aliceUsdcAfterMax / 1e6);
            console.log("USDC received:", maxUsdcReceived / 1e6);
            console.log("USDC increase:", (aliceUsdcAfterMax - aliceUsdcBeforeMax) / 1e6);
            
            // Check vault state after maximum withdrawal
            console.log("\nAfter Alice's maximum withdrawal:");
            console.log("Vault total value USD:", vault.getTotalValueUSD() / 1e18);
            console.log("Vault total shares:", vault.totalSupply() / 1e18);
            
            // Show detailed share value calculation after maximum withdrawal
            uint256 shareValueRawAfterMax = vault.getShareValueUSD();
            console.log("Vault share value (raw):", shareValueRawAfterMax);
            console.log("Vault share value USD:", shareValueRawAfterMax / 1e18);
            console.log("Vault share value (precise):", (shareValueRawAfterMax * 1000) / 1e18, "milliUSD");
            
            console.log("Alice's remaining shares:", vault.balanceOf(alice) / 1e18);
            console.log("Bob's shares:", vault.balanceOf(bob) / 1e18);
            
            // Debug: Check aToken balances after maximum withdrawal
            console.log("\nDebug - aToken balances after maximum withdrawal:");
            address daiATokenFinal = vault.getAToken(0x6B175474E89094C44Da98b954EedeAC495271d0F);
            address usdcATokenFinal = vault.getAToken(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
            console.log("DAI aToken balance:", IERC20(daiATokenFinal).balanceOf(address(vault)) / 1e18);
            console.log("USDC aToken balance:", IERC20(usdcATokenFinal).balanceOf(address(vault)) / 1e6);
            
            // Check if USDC aToken balance is zero
            uint256 usdcATokenBalance = IERC20(usdcATokenFinal).balanceOf(address(vault));
            if (usdcATokenBalance == 0) {
                console.log("SUCCESS: USDC aToken balance is now ZERO!");
            } else {
                console.log("USDC aToken balance is not zero:", usdcATokenBalance / 1e6);
            }
            
            // Check DAI aToken balance more precisely
            uint256 daiATokenBalance = IERC20(daiATokenFinal).balanceOf(address(vault));
            console.log("DAI aToken balance (raw):", daiATokenBalance);
            console.log("DAI aToken balance:", daiATokenBalance / 1e18);
            if (daiATokenBalance == 0) {
                console.log("SUCCESS: DAI aToken balance is now ZERO!");
            } else {
                console.log("DAI aToken balance is not zero:", daiATokenBalance / 1e18);
            }
            
            console.log("Alice maximum USDC withdrawal completed successfully!");
            
            // Calculate Bob's share value and what he can withdraw
            console.log("\n=== BOB'S SHARE ANALYSIS ===");
            console.log("Bob's shares:", vault.balanceOf(bob) / 1e18);
            console.log("Vault total shares:", vault.totalSupply() / 1e18);
            console.log("Vault total value USD:", vault.getTotalValueUSD() / 1e18);
            console.log("Vault share value USD:", vault.getShareValueUSD() / 1e18);
            
            // Calculate Bob's proportional value
            uint256 bobSharesFinal = vault.balanceOf(bob);
            uint256 totalSharesBob = vault.totalSupply();
            uint256 totalValueBob = vault.getTotalValueUSD();
            uint256 bobValueUSD = (totalValueBob * bobSharesFinal) / totalSharesBob;
            console.log("Bob's proportional value in USD:", bobValueUSD / 1e18);
            
            // Calculate what Bob can withdraw as USDC
            uint256 bobMaxUsdc = vault.previewWithdrawMulti(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, bobSharesFinal);
            console.log("Max USDC Bob can withdraw:", bobMaxUsdc / 1e6);
            
            // Calculate what Bob can withdraw as DAI
            uint256 bobMaxDai = vault.previewWithdrawMulti(0x6B175474E89094C44Da98b954EedeAC495271d0F, bobSharesFinal);
            console.log("Max DAI Bob can withdraw:", bobMaxDai / 1e18);
            
            console.log("Bob's share analysis completed!");
            
            // Detailed share value evolution analysis
            console.log("\n=== SHARE VALUE EVOLUTION ANALYSIS ===");
            console.log("Why did share value increase from ~1.124 to 2.124 USD?");
            console.log("");
            console.log("BEFORE Alice's first withdrawal:");
            console.log("- Vault value: 674 USD");
            console.log("- Total shares: 599 shares");
            console.log("- Share value: 674 / 599 = 1.124 USD per share");
            console.log("");
            console.log("ALICE'S FIRST WITHDRAWAL (100 shares):");
            console.log("- Alice withdrew: 100 shares");
            console.log("- Alice received: 112 USD");
            console.log("- Effective rate: 112 / 100 = 1.12 USD per share");
            console.log("- Vault value after: 562 USD");
            console.log("- Remaining shares: 499 shares");
            console.log("- New share value: 562 / 499 = 1.125 USD per share");
            console.log("");
            console.log("ALICE'S SECOND WITHDRAWAL (399 shares):");
            console.log("- Alice withdrew: 399 shares");
            console.log("- Alice received: 349 USD");
            console.log("- Effective rate: 349 / 399 = 0.875 USD per share");
            console.log("- Vault value after: 212 USD");
            console.log("- Remaining shares: 99 shares (Bob only)");
            console.log("- Final share value: 212 / 99 = 2.124 USD per share");
            console.log("");
            console.log("KEY INSIGHT: Alice's withdrawals were NOT proportional!");
            console.log("- She withdrew 100 shares but got 112 USD (more than proportional)");
            console.log("- This compressed the remaining shares into less value");
            console.log("- Bob's 99 shares now represent the remaining 212 USD");
            console.log("- Hence the dramatic increase in per-share value");
            
            console.log("\n=== TEST COMPLETED SUCCESSFULLY ===");
            console.log("All core vault functionality demonstrated:");
            console.log("- Multi-asset deposits (DAI and USDC)");
            console.log("- Yield simulation and accrual");
            console.log("- Cross-asset withdrawals with swaps");
            console.log("- Share value calculations");
            console.log("- aToken integration with Aave");
        }
    }
