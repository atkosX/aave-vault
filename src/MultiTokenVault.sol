// SPDX-License-Identifier: UNLICENSED
// All Rights Reserved © AaveCo

pragma solidity ^0.8.26;

import {ERC20Upgradeable} from 'lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol';
import {OwnableUpgradeable} from 'lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol';
import {PausableUpgradeable} from 'lib/openzeppelin-contracts-upgradeable/contracts/utils/PausableUpgradeable.sol';
import {ReentrancyGuard} from 'lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol';
import {SafeERC20} from 'lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {IERC20} from 'lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {EIP712Upgradeable} from 'lib/openzeppelin-contracts-upgradeable/contracts/utils/cryptography/EIP712Upgradeable.sol';
import {Math} from 'lib/openzeppelin-contracts/contracts/utils/math/Math.sol';

import {IncentivizedERC20} from 'lib/aave-v3-origin/src/contracts/protocol/tokenization/base/IncentivizedERC20.sol';
import {IPoolAddressesProvider} from 'lib/aave-v3-origin/src/contracts/interfaces/IPoolAddressesProvider.sol';
import {IPool} from 'lib/aave-v3-origin/src/contracts/interfaces/IPool.sol';
import {IAToken} from 'lib/aave-v3-origin/src/contracts/interfaces/IAToken.sol';
import {DataTypes as AaveDataTypes} from 'lib/aave-v3-origin/src/contracts/protocol/libraries/types/DataTypes.sol';
import {WadRayMath} from 'lib/aave-v3-origin/src/contracts/protocol/libraries/math/WadRayMath.sol';
import {IRewardsController} from 'lib/aave-v3-origin/src/contracts/rewards/interfaces/IRewardsController.sol';
import {IPriceOracle} from 'lib/aave-v3-origin/src/contracts/interfaces/IPriceOracle.sol';
import {IMultiTokenVault} from './interfaces/IMultiTokenVault.sol';
import {MultiTokenVaultStorage} from './MultiTokenVaultStorage.sol';
import {VRFV2PlusWrapperConsumerBase} from 'lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol';
import {VRFV2PlusClient} from 'lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol';
import {LinkTokenInterface} from 'lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol';

interface IMockDEX {
    function swap(address tokenIn, address tokenOut, uint256 amountIn) external returns (uint256 amountOut);
    function getQuote(address tokenIn, address tokenOut, uint256 amountIn) external view returns (uint256 amountOut);
}

/**
 * @title MultiTokenVault
 * @author Aave Protocol
 * @notice A multi-asset ERC-4626 vault for Aave V3, supporting multiple ERC20 tokens with unified shares.
 */
contract MultiTokenVault is ERC20Upgradeable, OwnableUpgradeable, PausableUpgradeable, ReentrancyGuard, EIP712Upgradeable, MultiTokenVaultStorage, IMultiTokenVault, VRFV2PlusWrapperConsumerBase {
    using SafeERC20 for IERC20;
    using Math for uint256;

    IPoolAddressesProvider public immutable POOL_ADDRESSES_PROVIDER;
    IPool public immutable AAVE_POOL;
    uint16 public immutable REFERRAL_CODE;
    address public constant PRICE_ORACLE = 0x54586bE62E3c3580375aE3723C145253060Ca0C2; // Aave V3 Price Oracle, using single price for assignment purposes
    
    // VRF Configuration
    address public constant LINK_ADDRESS = 0x514910771AF9Ca656af840dff83E8264EcF986CA; // LINK token
    address public constant VRF_WRAPPER = 0x02aae1A04f9828517b3007f83f6181900CaD910c; // VRF Wrapper
    uint32 public constant VRF_CALLBACK_GAS_LIMIT = 100000;
    uint16 public constant VRF_REQUEST_CONFIRMATIONS = 3;
    uint32 public constant VRF_NUM_WORDS = 1; // We only need 1 random number for winner selection

    // Additional events not in interface
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event YieldAccrued(address indexed asset, uint256 newYield, uint256 newFeesEarned, uint256 newVaultBalance);
    event FeesWithdrawn(address indexed to, uint256 amount, uint256 lastVaultBalance, uint256 accumulatedFees);
    event RewardsClaimed(address indexed to, address[] rewardsList, uint256[] claimedAmounts);
    event EmergencyRescue(address indexed token, address indexed to, uint256 amount);
    
    // VRF Events
    event RandomYieldRequestSent(uint256 requestId, uint32 numWords);
    event RandomYieldDistributed(uint256 requestId, address[] winners, uint256[] amounts);
    event YieldDistributionRequested(uint256 totalYield, uint256 winnerCount);

    /**
     * @dev Constructor.
     * @param poolAddressesProvider The address of the Aave v3 Pool Addresses Provider
     * @param referralCode The Aave referral code to use for deposits from this vault
     */
    constructor(IPoolAddressesProvider poolAddressesProvider, uint16 referralCode) VRFV2PlusWrapperConsumerBase(VRF_WRAPPER) {
        // _disableInitializers(); // Removed to allow initialization
        POOL_ADDRESSES_PROVIDER = poolAddressesProvider;
        AAVE_POOL = IPool(poolAddressesProvider.getPool());
        REFERRAL_CODE = referralCode;
    }

    /**
     * @notice Initializes the vault, setting the initial parameters and initializing inherited contracts.
     * @param owner The owner to set
     * @param initialFee The initial fee to set, expressed in wad, where 1e18 is 100%
     * @param shareName The name to set for this vault
     * @param shareSymbol The symbol to set for this vault
     * @param initialAssets Array of initial supported assets
     * @param initialAmounts Array of initial deposit amounts for each asset
     */
    function initialize(
        address owner,
        uint256 initialFee,
        string memory shareName,
        string memory shareSymbol,
        address[] memory initialAssets,
        uint256[] memory initialAmounts
    ) external initializer {
        require(owner != address(0), 'ZERO_ADDRESS_NOT_VALID');
        require(initialAssets.length == initialAmounts.length, 'ARRAY_LENGTH_MISMATCH');
        require(initialAssets.length > 0, 'NO_INITIAL_ASSETS');
        
        // Initialize inherited contracts
        __Ownable_init(owner);
        __ERC20_init(shareName, shareSymbol);
        __Pausable_init();
        __EIP712_init(shareName, '1');
        _setFee(initialFee);

        // Add initial assets first
        for (uint256 i = 0; i < initialAssets.length; i++) {
            _addSupportedAsset(initialAssets[i]);
        }

        // Handle initial deposits after initialization
        for (uint256 i = 0; i < initialAssets.length; i++) {
            if (initialAmounts[i] > 0) {
                _handleDepositMulti(initialAssets[i], initialAmounts[i], msg.sender, msg.sender, false);
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function addSupportedAsset(address asset) external onlyOwner whenNotPaused {
        require(!_isSupported[asset], 'Asset already supported');
        _addSupportedAsset(asset);
        emit AssetAdded(asset, _assetToAToken[asset]);
    }

    function addSupportedAsset(address asset, uint16 referralCode) external onlyOwner whenNotPaused {
        require(!_isSupported[asset], 'Asset already supported');
        _addSupportedAsset(asset);
        emit AssetAdded(asset, _assetToAToken[asset]);
    }

    function removeSupportedAsset(address asset) external onlyOwner whenNotPaused {
        require(_isSupported[asset], 'Asset not supported');
        require(IAToken(_assetToAToken[asset]).balanceOf(address(this)) == 0, 'Asset has balance');
        _removeSupportedAsset(asset);
        emit AssetRemoved(asset);
    }

    function getSupportedAssets() external view returns (address[] memory) {
        return _supportedAssets;
    }

    function getAToken(address asset) external view returns (address) {
        return _assetToAToken[asset];
    }

    function isAssetSupported(address asset) external view returns (bool) {
        return _isSupported[asset];
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function depositMulti(address asset, uint256 amount, address receiver) public whenNotPaused nonReentrant returns (uint256) {
        require(_isSupported[asset], 'Asset not supported');
        require(amount > 0, 'Amount must be > 0');
        return _handleDepositMulti(asset, amount, receiver, msg.sender, false);
    }

    function withdrawMulti(address asset, uint256 shares, address receiver, address owner) public whenNotPaused nonReentrant returns (uint256) {
        require(_isSupported[asset], 'Asset not supported');
        require(shares > 0, 'Shares must be > 0');
        require(balanceOf(owner) >= shares, 'Insufficient shares');
        return _handleWithdrawMulti(asset, shares, receiver, owner, msg.sender);
    }

    function getAssetValueUSD(address asset, uint256 amount) public view returns (uint256) {
        return _getAssetValueUSD(asset, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        MULTI-ASSET VAULT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getTotalValueUSD() public view returns (uint256) {
        uint256 totalValueUSD = 0;
        
        for (uint256 i = 0; i < _supportedAssets.length; i++) {
            address asset = _supportedAssets[i];
            address aToken = _assetToAToken[asset];
            
            // Get aToken balance (underlying + yield)
            uint256 aTokenBalance = IAToken(aToken).balanceOf(address(this));
            
            // Convert to USD value
            uint256 assetValueUSD = _getAssetValueUSD(asset, aTokenBalance);
            totalValueUSD += assetValueUSD;
        }
        
        return totalValueUSD;
    }

    function getShareValueUSD() public view returns (uint256) {
        uint256 totalValue = getTotalValueUSD();
        uint256 totalShares = totalSupply();
        
        if (totalShares == 0) {
            return 0;
        }
        
        return totalValue.mulDiv(1e18, totalShares, Math.Rounding.Floor);
    }

    function previewDepositMulti(address asset, uint256 amount) public view returns (uint256 shares) {
        require(_isSupported[asset], 'Asset not supported');
        
        uint256 valueUSD = _getAssetValueUSD(asset, amount);
        uint256 totalValueUSD = getTotalValueUSD();
        
        if (totalValueUSD == 0) {
            shares = valueUSD; // First deposit: 1:1 ratio
        } else {
            shares = valueUSD.mulDiv(totalSupply(), totalValueUSD, Math.Rounding.Floor);
        }
    }

    function previewWithdrawMulti(address asset, uint256 shares) public view returns (uint256 assets) {
        require(_isSupported[asset], 'Asset not supported');
        
        // Calculate user's proportional claim in USD
        uint256 totalValueUSD = getTotalValueUSD();
        uint256 shareOfValueUSD = shares.mulDiv(totalValueUSD, totalSupply(), Math.Rounding.Floor);
        
        // Convert USD value to requested asset amount
        assets = _getAssetAmountFromUSD(asset, shareOfValueUSD);
    }
    
    function setMockDEX(address mockDEX) external onlyOwner whenNotPaused {
        _mockDEX = mockDEX;
    }
    
    function getMockDEX() external view returns (address) {
        return _mockDEX;
    }
    
    function getAssetToAToken(address asset) external view returns (address) {
        return _assetToAToken[asset];
    }
    
    function getAccumulatedFees(address asset) external view returns (uint256) {
        return _accumulatedFees[asset];
    }

    /*//////////////////////////////////////////////////////////////
                          ONLY OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Pause the contract
     * @dev Pauses all state-changing functions except emergency functions
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause the contract
     * @dev Unpauses all state-changing functions
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Check if the contract is paused
     * @return True if the contract is paused, false otherwise
     */
    function isPaused() external view returns (bool) {
        return paused();
    }

    // Update setFee to adjust the fee for all supported assets consistently
    function setFee(uint256 newFee) public onlyOwner whenNotPaused {
        _accrueYield();
        require(newFee <= SCALE, 'FEE_TOO_HIGH');
        uint256 oldFee = _fee;
        _fee = newFee;
        emit FeeUpdated(oldFee, newFee);
    }

    function withdrawFees(address asset, address to, uint256 amount) public onlyOwner whenNotPaused nonReentrant {
        require(_isSupported[asset], 'Asset not supported');
        _accrueYield();
        require(amount <= _accumulatedFees[asset], 'INSUFFICIENT_FEES');

        _accumulatedFees[asset] -= amount;
        
        AAVE_POOL.withdraw(asset, amount, to);

        _lastVaultBalance[asset] = uint128(IAToken(_assetToAToken[asset]).balanceOf(address(this)));

        emit FeesWithdrawn(to, amount, _lastVaultBalance[asset], _accumulatedFees[asset]);
    }

    function claimRewards(address asset, address to) public onlyOwner whenNotPaused nonReentrant {
        require(_isSupported[asset], 'Asset not supported');
        require(to != address(0), 'CANNOT_CLAIM_TO_ZERO_ADDRESS');

        address[] memory assets = new address[](1);
        assets[0] = _assetToAToken[asset];
        (address[] memory rewardsList, uint256[] memory claimedAmounts) = IRewardsController(
            address(IncentivizedERC20(_assetToAToken[asset]).getIncentivesController())
        ).claimAllRewards(assets, to);

        emit RewardsClaimed(to, rewardsList, claimedAmounts);
    }

    function emergencyRescue(address token, address to, uint256 amount) public onlyOwner nonReentrant {
        require(_isSupported[token] == false, 'CANNOT_RESCUE_SUPPORTED_ASSET');
        IERC20(token).safeTransfer(to, amount);
        emit EmergencyRescue(token, to, amount);
    }

    // Implement harvestYield to leverage multiple aTokens
    function harvestYield(address toAsset) external onlyOwner whenNotPaused nonReentrant {
        require(_isSupported[toAsset], 'Asset not supported');

        // Calculate total yield in USD

        uint256 currentTotalValue = getTotalValueUSD();
        uint256 totalDepositedValue = _totalDepositedValueUSD;
        uint256 yieldUSD = currentTotalValue > totalDepositedValue ? currentTotalValue - totalDepositedValue : 0;

        if (yieldUSD > 0) {
            // Convert yield to requested asset
            uint256 price = IPriceOracle(PRICE_ORACLE).getAssetPrice(toAsset);
            uint256 decimals = 18;
            
            uint256 adjustedPrice = price * (10 ** (18 - 8));
            uint256 yieldAmount = yieldUSD.mulDiv(10 ** decimals, adjustedPrice, Math.Rounding.Floor);
 
            AAVE_POOL.withdraw(toAsset, yieldAmount, owner());

            emit YieldHarvested(owner(), toAsset, yieldAmount);
        }
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getClaimableFees(address asset) public view returns (uint256) {
        require(_isSupported[asset], 'Asset not supported');
        address aToken = _assetToAToken[asset];
        uint256 newVaultBalance = IAToken(aToken).balanceOf(address(this));

        if (newVaultBalance <= _lastVaultBalance[asset]) {
            return _accumulatedFees[asset];
        }

        uint256 newYield = newVaultBalance - _lastVaultBalance[asset];
        uint256 newFees = newYield.mulDiv(_fee, SCALE, Math.Rounding.Floor);

        return _accumulatedFees[asset] + newFees;
    }

    function getFee() public view returns (uint256) {
        return _fee;
    }

    function domainSeparator() public view returns (bytes32) {
        return _domainSeparatorV4();
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _addSupportedAsset(address asset) internal {
        AaveDataTypes.ReserveDataLegacy memory reserveData = AAVE_POOL.getReserveData(asset);
        address aTokenAddress = reserveData.aTokenAddress;
        require(aTokenAddress != address(0), 'ASSET_NOT_SUPPORTED');

        _assetToAToken[asset] = aTokenAddress;
        _supportedAssets.push(asset);
        _isSupported[asset] = true;

        IERC20(asset).approve(address(AAVE_POOL), type(uint256).max);
    }

    function _removeSupportedAsset(address asset) internal {
        for (uint256 i = 0; i < _supportedAssets.length; i++) {
            if (_supportedAssets[i] == asset) {
                _supportedAssets[i] = _supportedAssets[_supportedAssets.length - 1];
                _supportedAssets.pop();
                break;
            }
        }

        _isSupported[asset] = false;
        delete _assetToAToken[asset];
    }

    function _setFee(uint256 newFee) internal {
        require(newFee <= SCALE, 'FEE_TOO_HIGH');
        uint256 oldFee = _fee;
        _fee = newFee;
        emit FeeUpdated(oldFee, newFee);
    }

    // Update _accrueYield to ensure yield is calculated and accrued consistently across all supported assets
    function _accrueYield() internal {
        for (uint256 i = 0; i < _supportedAssets.length; i++) {
            address asset = _supportedAssets[i];
            address aToken = _assetToAToken[asset];

            uint256 newVaultBalance = IAToken(aToken).balanceOf(address(this));

            if (newVaultBalance > _lastVaultBalance[asset]) {
                uint256 newYield = newVaultBalance - _lastVaultBalance[asset];
                uint256 newFeesEarned = newYield.mulDiv(_fee, SCALE, Math.Rounding.Floor);
                _accumulatedFees[asset] += newFeesEarned;
                _lastVaultBalance[asset] = uint128(newVaultBalance);
                emit YieldAccrued(asset, newYield, newFeesEarned, newVaultBalance);
            }
        }
    }

    function _handleDepositMulti(address asset, uint256 amount, address receiver, address depositor, bool asAToken) internal returns (uint256) {
        _accrueYield();
        
        // Calculate USD value of deposit
        uint256 valueUSD = _getAssetValueUSD(asset, amount);
        
        // Calculate shares based on total vault USD value
        uint256 totalValueUSD = getTotalValueUSD();
        uint256 shares;
        
        if (totalValueUSD == 0) {
            shares = valueUSD; // First deposit: 1:1 ratio
        } else {
            shares = valueUSD.mulDiv(totalSupply(), totalValueUSD, Math.Rounding.Floor);
        }
        
        require(shares > 0, 'ZERO_SHARES');
        _baseDepositMulti(asset, amount, shares, depositor, receiver, asAToken);
        
        // Update tracking
        _totalDepositedValueUSD += valueUSD;
        _assetDepositedValueUSD[asset] += valueUSD;
        
        // Add participant for VRF
        _addParticipant(receiver);
        
        return shares;
    }

    function _handleWithdrawMulti(address asset, uint256 shares, address receiver, address owner, address allowanceTarget) internal returns (uint256) {
        _accrueYield();
        
        // Calculate user's proportional claim in USD
        uint256 totalValueUSD = getTotalValueUSD();
        uint256 shareOfValueUSD = shares.mulDiv(totalValueUSD, totalSupply(), Math.Rounding.Floor);
        
        // Convert USD value to requested asset amount
        uint256 requestedAmount = _getAssetAmountFromUSD(asset, shareOfValueUSD);
        
        // Check if we have enough of the requested asset
        uint256 availableAmount = IAToken(_assetToAToken[asset]).balanceOf(address(this));
        
        if (availableAmount >= requestedAmount) {
            // Direct withdrawal - we have enough
            if (allowanceTarget != owner) {
                _spendAllowance(owner, allowanceTarget, shares);
            }
            _burn(owner, shares);
            _baseWithdrawMulti(asset, requestedAmount, receiver);
            
            // Remove participant if no shares left
            _removeParticipant(owner);
            
            return requestedAmount;
        } else {
            // Need to swap other assets to get the requested asset
            if (allowanceTarget != owner) {
                _spendAllowance(owner, allowanceTarget, shares);
            }
            _burn(owner, shares);
            
            // Remove participant if no shares left
            _removeParticipant(owner);
            
            return _swapAndWithdraw(asset, requestedAmount, receiver);
        }
    }

    function _getAssetValueUSD(address asset, uint256 amount) internal view returns (uint256) {
        uint256 price = IPriceOracle(PRICE_ORACLE).getAssetPrice(asset);
        
        // Handle different decimal places for different tokens
        // Temporary fix for USDC
        uint256 decimals;
        if (asset == 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48) { // USDC
            decimals = 6;
        } else {
            decimals = 18; // DAI, WETH, etc.
        }
        
        uint256 adjustedPrice = price * (10 ** (18 - 8));
        return adjustedPrice.mulDiv(amount, 10 ** decimals, Math.Rounding.Floor);
    }
    
    function _getAssetAmountFromUSD(address asset, uint256 usdValue) internal view returns (uint256) {
        uint256 price = IPriceOracle(PRICE_ORACLE).getAssetPrice(asset);
        
        // Handle different decimal places for different tokens
        uint256 decimals;
        if (asset == 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48) { // USDC
            decimals = 6;
        } else {
            decimals = 18; // DAI, WETH, etc.
        }
        
        uint256 adjustedPrice = price * (10 ** (18 - 8));
        return usdValue.mulDiv(10 ** decimals, adjustedPrice, Math.Rounding.Floor);
    }
    
    function _swapAndWithdraw(address targetAsset, uint256 amountNeeded, address receiver) internal returns (uint256) {
        require(_mockDEX != address(0), 'Mock DEX not set');
        
        // Find which assets we have available for swapping
        for (uint i = 0; i < _supportedAssets.length; i++) {
            address availableAsset = _supportedAssets[i];
            if (availableAsset == targetAsset) continue;
            
            uint256 availableBalance = IAToken(_assetToAToken[availableAsset]).balanceOf(address(this));
            if (availableBalance > 0) {
                // Use all available balance for swap (since we have 1:1 rate)
                uint256 swapAmount = availableBalance;
                
                // Withdraw from Aave
                AAVE_POOL.withdraw(availableAsset, swapAmount, address(this));
                
                // Approve and swap using mock DEX
                IERC20(availableAsset).approve(_mockDEX, swapAmount);
                uint256 receivedAmount = IMockDEX(_mockDEX).swap(availableAsset, targetAsset, swapAmount);
                
                // Transfer to user
                IERC20(targetAsset).transfer(receiver, receivedAmount);
                return receivedAmount;
            }
        }
        
        revert('Insufficient liquidity for withdrawal');
    }
    
    function _calculateSwapAmount(address fromAsset, address toAsset, uint256 targetAmount) internal view returns (uint256) {
        // For 1:1 exchange rate, we need the same amount
        // Since MockDEX has 1:1 rate, we just return the target amount
        return targetAmount;
    }

    function _baseDepositMulti(address asset, uint256 assets, uint256 shares, address depositor, address receiver, bool asAToken) private {
        if (asAToken) {
            IAToken(_assetToAToken[asset]).transferFrom(depositor, address(this), assets);
        } else {
            IERC20(asset).safeTransferFrom(depositor, address(this), assets);
            AAVE_POOL.supply(asset, assets, address(this), REFERRAL_CODE);
        }
        
        _lastVaultBalance[asset] = uint128(IAToken(_assetToAToken[asset]).balanceOf(address(this)));
        _mint(receiver, shares);
        
        emit DepositMulti(depositor, receiver, asset, assets, shares);
    }

    function _baseWithdrawMulti(address asset, uint256 assets, address receiver) private {
        AAVE_POOL.withdraw(asset, assets, receiver);
        _lastVaultBalance[asset] = uint128(IAToken(_assetToAToken[asset]).balanceOf(address(this)));
    }

    // MOCK FUNCTION: Simulate yield generation for testing
    function simulateYield(uint256 amount, address asset) external onlyOwner whenNotPaused nonReentrant {
        require(_isSupported[asset], 'Asset not supported');
        
        // Supply real tokens to Aave to get real aTokens
        IERC20(asset).approve(address(AAVE_POOL), amount);
        AAVE_POOL.supply(asset, amount, address(this), REFERRAL_CODE);
        
        // Update tracking
        _lastVaultBalance[asset] += uint128(amount);
        emit YieldAccrued(asset, amount, _accumulatedFees[asset], _lastVaultBalance[asset]);
    }

    /*//////////////////////////////////////////////////////////////
                        VRF YIELD DISTRIBUTION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Request random yield distribution to selected participants
     * @param totalYield Total yield amount to distribute
     * @param winnerCount Number of winners to select
     * @param toAsset Asset to distribute yield in
     * @param enableNativePayment Whether to pay with native ETH or LINK
     */
    function requestRandomYieldDistribution(
        uint256 totalYield,
        uint256 winnerCount,
        address toAsset,
        bool enableNativePayment
    ) external onlyOwner whenNotPaused nonReentrant returns (uint256) {
        require(_isSupported[toAsset], 'Asset not supported');
        require(winnerCount > 0, 'Winner count must be > 0');
        require(totalYield > 0, 'Total yield must be > 0');
        
        // Check if we have enough participants
        uint256 totalParticipants = _getTotalParticipants();
        require(winnerCount <= totalParticipants, 'Not enough participants');
        
        bytes memory extraArgs = VRFV2PlusClient._argsToBytes(
            VRFV2PlusClient.ExtraArgsV1({nativePayment: enableNativePayment})
        );
        
        uint256 requestId;
        uint256 reqPrice;
        
        if (enableNativePayment) {
            (requestId, reqPrice) = requestRandomnessPayInNative(
                VRF_CALLBACK_GAS_LIMIT,
                VRF_REQUEST_CONFIRMATIONS,
                VRF_NUM_WORDS,
                extraArgs
            );
        } else {
            (requestId, reqPrice) = requestRandomness(
                VRF_CALLBACK_GAS_LIMIT,
                VRF_REQUEST_CONFIRMATIONS,
                VRF_NUM_WORDS,
                extraArgs
            );
        }
        
        _yieldDistributionRequests[requestId] = YieldDistributionRequest({
            totalYield: totalYield,
            winnerCount: winnerCount,
            toAsset: toAsset,
            fulfilled: false
        });
        
        _requestIds.push(requestId);
        _lastRequestId = requestId;
        
        emit RandomYieldRequestSent(requestId, VRF_NUM_WORDS);
        emit YieldDistributionRequested(totalYield, winnerCount);
        
        return requestId;
    }

    /**
     * @notice VRF callback function to distribute yield to random winners
     */
    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override nonReentrant {
        require(_yieldDistributionRequests[_requestId].totalYield > 0, 'Request not found');
        require(!_yieldDistributionRequests[_requestId].fulfilled, 'Request already fulfilled');
        
        YieldDistributionRequest storage request = _yieldDistributionRequests[_requestId];
        request.fulfilled = true;
        
        // Select random winners
        address[] memory winners = _selectRandomWinners(_randomWords[0], request.winnerCount);
        
        // Distribute yield to winners
        uint256[] memory amounts = _distributeYieldToWinners(
            winners,
            request.totalYield,
            request.toAsset
        );
        
        emit RandomYieldDistributed(_requestId, winners, amounts);
    }

    /**
     * @notice Get total number of participants (MTV token holders)
     */
    function _getTotalParticipants() internal view returns (uint256) {
        return _participants.length;
    }
    
    /**
     * @notice Add participant to VRF pool when they get shares
     */
    function _addParticipant(address participant) internal {
        if (!_isParticipant[participant]) {
            _participants.push(participant);
            _isParticipant[participant] = true;
        }
    }
    
    /**
     * @notice Remove participant from VRF pool when they have no shares
     */
    function _removeParticipant(address participant) internal {
        if (_isParticipant[participant] && balanceOf(participant) == 0) {
            _isParticipant[participant] = false;
            // Remove from array (keep it simple for now)
            for (uint256 i = 0; i < _participants.length; i++) {
                if (_participants[i] == participant) {
                    _participants[i] = _participants[_participants.length - 1];
                    _participants.pop();
                    break;
                }
            }
        }
    }

    /**
     * @notice Select random winners from participants
     */
    function _selectRandomWinners(uint256 randomSeed, uint256 winnerCount) internal view returns (address[] memory) {
        require(_participants.length > 0, 'No participants');
        require(winnerCount <= _participants.length, 'Not enough participants');
        
        address[] memory winners = new address[](winnerCount);
        address[] memory availableParticipants = new address[](_participants.length);
        
        for (uint256 i = 0; i < _participants.length; i++) {
            availableParticipants[i] = _participants[i];
        }
        
        uint256 remainingCount = _participants.length;
        
        // Select winners using Fisher-Yates shuffle algorithm
        for (uint256 i = 0; i < winnerCount; i++) {
            uint256 randomIndex = randomSeed % remainingCount;
            
            winners[i] = availableParticipants[randomIndex];
            
            // Move last element to selected position to avoid duplicates
            availableParticipants[randomIndex] = availableParticipants[remainingCount - 1];
            remainingCount--;
            
            // Use next part of random seed for next selection
            randomSeed = uint256(keccak256(abi.encodePacked(randomSeed)));
        }
        
        return winners;
    }

    /**
     * @notice Distribute yield to selected winners
     */
    function _distributeYieldToWinners(
        address[] memory winners,
        uint256 totalYield,
        address toAsset
    ) internal returns (uint256[] memory) {
        uint256[] memory amounts = new uint256[](winners.length);
        uint256 yieldPerWinner = totalYield / winners.length;
        
        for (uint256 i = 0; i < winners.length; i++) {
            amounts[i] = yieldPerWinner;
            
            // Transfer yield to winner
            if (yieldPerWinner > 0) {
                AAVE_POOL.withdraw(toAsset, yieldPerWinner, winners[i]);
            }
        }
        
        return amounts;
    }

    /**
     * @notice Get VRF request status
     */
    function getYieldDistributionRequestStatus(uint256 requestId) external view returns (
        uint256 totalYield,
        uint256 winnerCount,
        address toAsset,
        bool fulfilled
    ) {
        YieldDistributionRequest memory request = _yieldDistributionRequests[requestId];
        return (request.totalYield, request.winnerCount, request.toAsset, request.fulfilled);
    }
    
    /**
     * @notice Get list of participants for VRF
     */
    function getParticipants() external view returns (address[] memory) {
        return _participants;
    }
    
    /**
     * @notice Check if address is a participant
     */
    function isParticipant(address participant) external view returns (bool) {
        return _isParticipant[participant];
    }

    /**
     * @notice Withdraw LINK tokens
     */
    function withdrawLink() external onlyOwner whenNotPaused nonReentrant {
        LinkTokenInterface link = LinkTokenInterface(LINK_ADDRESS);
        require(link.transfer(owner(), link.balanceOf(address(this))), 'LINK transfer failed');
    }

    /**
     * @notice Withdraw native ETH
     */
    function withdrawNative(uint256 amount) external onlyOwner whenNotPaused nonReentrant {
        (bool success, ) = payable(owner()).call{value: amount}('');
        require(success, 'Native withdrawal failed');
    }

    receive() external payable {
        // Allow contract to receive ETH for VRF payments
    }
}
