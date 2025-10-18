// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {MultiTokenVault} from "../src/MultiTokenVault.sol";
import {IPoolAddressesProvider} from "lib/aave-v3-origin/src/contracts/interfaces/IPoolAddressesProvider.sol";

contract DeployMultiTokenVault is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying MultiTokenVault with account:", deployer);
        console.log("Account balance:", deployer.balance);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy MultiTokenVault
        MultiTokenVault vault = new MultiTokenVault(
            IPoolAddressesProvider(0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e), // Aave V3 Pool Addresses Provider
            0 // referral code
        );
        
        console.log("MultiTokenVault deployed at:", address(vault));
        
        // Initialize with common assets
        address[] memory initialAssets = new address[](3);
        uint256[] memory initialAmounts = new uint256[](3);
        
        initialAssets[0] = 0x6B175474E89094C44Da98b954EedeAC495271d0F; // DAI
        initialAssets[1] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
        initialAssets[2] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH
        
        initialAmounts[0] = 0; // No initial deposit
        initialAmounts[1] = 0; // No initial deposit
        initialAmounts[2] = 0; // No initial deposit
        
        vault.initialize(
            deployer, // owner
            1e17, // 10% fee
            "MultiToken Vault",
            "MTV",
            initialAssets,
            initialAmounts
        );
        
        console.log("MultiTokenVault initialized");
        console.log("Owner:", vault.owner());
        console.log("Fee:", vault.getFee());
        console.log("Supported assets:", vault.getSupportedAssets().length);
        
        vm.stopBroadcast();
    }
}
