// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/VRFDirectFundingConsumer.sol";

contract DeployVRF is Script {
    function run() external {
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80; // Test private key
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying VRFDirectFundingConsumer...");
        console.log("Deployer address:", deployer);
        console.log("Deployer balance:", deployer.balance);
        
        vm.startBroadcast(deployerPrivateKey);
        
        VRFDirectFundingConsumer vrfConsumer = new VRFDirectFundingConsumer();
        
        vm.stopBroadcast();
        
        console.log("VRFDirectFundingConsumer deployed at:", address(vrfConsumer));
        console.log("Wrapper address:", vrfConsumer.wrapperAddress());
        console.log("LINK address:", vrfConsumer.linkAddress());
        console.log("Callback gas limit:", vrfConsumer.callbackGasLimit());
        console.log("Request confirmations:", vrfConsumer.requestConfirmations());
        console.log("Number of words:", vrfConsumer.numWords());
    }
}
