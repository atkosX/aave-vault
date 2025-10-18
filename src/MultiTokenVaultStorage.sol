// SPDX-License-Identifier: UNLICENSED
// All Rights Reserved © AaveCo

pragma solidity ^0.8.26;

/**
 * @title MultiTokenVaultStorage
 * @author Aave Protocol
 * @notice Contains storage variables for the MultiTokenVault.
 */
abstract contract MultiTokenVaultStorage {
    // Multi-asset mappings
    mapping(address => address) internal _assetToAToken;
    address[] internal _supportedAssets;
    mapping(address => bool) internal _isSupported;
    
    // Fee management (per asset)
    mapping(address => uint256) internal _lastVaultBalance; // Per asset
    mapping(address => uint256) internal _accumulatedFees;  // Per asset
    uint256 internal _fee;
    
    // USD value tracking
    uint256 internal _totalDepositedValueUSD;
    mapping(address => uint256) internal _assetDepositedValueUSD;
    
    // Mock DEX integration
    address internal _mockDEX;
    
    // VRF State Variables
    struct YieldDistributionRequest {
        uint256 totalYield;
        uint256 winnerCount;
        address toAsset;
        bool fulfilled;
    }
    
    mapping(uint256 => YieldDistributionRequest) internal _yieldDistributionRequests;
    uint256[] internal _requestIds;
    uint256 internal _lastRequestId;
    
    // Constants
    uint256 internal constant SCALE = 1e18;
}
