// SPDX-License-Identifier: UNLICENSED
// All Rights Reserved © AaveCo

pragma solidity ^0.8.26;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * @title IMultiTokenVault
 * @author Aave Protocol
 * @notice Interface for Multi-Token Vault supporting multiple ERC20 tokens
 */
interface IMultiTokenVault is IERC20 {
    /**
     * @notice Emitted when a new asset is added to the vault
     * @param asset The underlying asset address
     * @param aToken The corresponding aToken address
     */
    event AssetAdded(address indexed asset, address indexed aToken);

    /**
     * @notice Emitted when an asset is removed from the vault
     * @param asset The underlying asset address
     */
    event AssetRemoved(address indexed asset);

    /**
     * @notice Emitted when a multi-asset deposit is made
     * @param depositor The address making the deposit
     * @param receiver The address receiving the shares
     * @param asset The underlying asset being deposited
     * @param amount The amount of assets deposited
     * @param shares The amount of shares minted
     */
    event DepositMulti(
        address indexed depositor,
        address indexed receiver,
        address indexed asset,
        uint256 amount,
        uint256 shares
    );

    /**
     * @notice Emitted when a multi-asset withdrawal is made
     * @param caller The address calling the withdrawal
     * @param receiver The address receiving the assets
     * @param asset The underlying asset being withdrawn
     * @param assets The amount of assets withdrawn
     * @param shares The amount of shares burned
     */
    event WithdrawMulti(
        address indexed caller,
        address indexed receiver,
        address indexed asset,
        uint256 assets,
        uint256 shares
    );

    /**
     * @notice Emitted when yield is harvested
     * @param to The address receiving the yield
     * @param asset The asset the yield is harvested in
     * @param amount The amount of yield harvested
     */
    event YieldHarvested(address indexed to, address indexed asset, uint256 amount);

    /**
     * @notice Adds a new supported asset to the vault
     * @param asset The underlying asset address
     * @param referralCode The Aave referral code for this asset
     */
    function addSupportedAsset(address asset, uint16 referralCode) external;

    /**
     * @notice Removes a supported asset from the vault
     * @param asset The underlying asset address
     */
    function removeSupportedAsset(address asset) external;

    /**
     * @notice Deposits a specific asset into the vault
     * @param asset The underlying asset to deposit
     * @param amount The amount of assets to deposit
     * @param receiver The address to receive the shares
     * @return shares The amount of shares minted
     */
    function depositMulti(address asset, uint256 amount, address receiver) external returns (uint256 shares);

    /**
     * @notice Withdraws a specific asset from the vault
     * @param asset The underlying asset to withdraw
     * @param shares The amount of shares to redeem
     * @param receiver The address to receive the assets
     * @param owner The address that owns the shares
     * @return assets The amount of assets withdrawn
     */
    function withdrawMulti(address asset, uint256 shares, address receiver, address owner) external returns (uint256 assets);

    /**
     * @notice Gets all supported assets
     * @return assets Array of supported asset addresses
     */
    function getSupportedAssets() external view returns (address[] memory assets);

    /**
     * @notice Gets the aToken address for a given asset
     * @param asset The underlying asset address
     * @return aToken The corresponding aToken address
     */
    function getAToken(address asset) external view returns (address aToken);

    /**
     * @notice Checks if an asset is supported
     * @param asset The underlying asset address
     * @return isSupported True if the asset is supported
     */
    function isAssetSupported(address asset) external view returns (bool isSupported);

    /**
     * @notice Harvests yield from all assets and converts to a specific asset
     * @param toAsset The asset to harvest yield in
     */
    function harvestYield(address toAsset) external;

    /**
     * @notice Gets the USD value of a specific asset amount
     * @param asset The underlying asset address
     * @param amount The amount of the asset
     * @return valueUSD The USD value in 18 decimals
     */
    function getAssetValueUSD(address asset, uint256 amount) external view returns (uint256 valueUSD);
    function getTotalValueUSD() external view returns (uint256);
    function getShareValueUSD() external view returns (uint256);
    function previewDepositMulti(address asset, uint256 amount) external view returns (uint256 shares);
    function previewWithdrawMulti(address asset, uint256 shares) external view returns (uint256 assets);
    function getFee() external view returns (uint256);
    function setFee(uint256 newFee) external;
    function withdrawFees(address asset, address to, uint256 amount) external;
}
