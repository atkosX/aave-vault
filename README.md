# Layer3 - Solidity Code Project

## **Objective**

Build a vault that allows users to **deposit ERC20 tokens**, **safely withdraw their principal**, and **generate yield** through a real protocol integration such as **Aave**.

All yield should be **trackable** and **fully extractable** by an admin or designated role.

## **Inspiration & Reference**

This project takes **reference and inspiration** from [Aave's ATokenVault](https://github.com/aave/Aave-Vault/blob/main/src/ATokenVault.sol) for the core vault functionality, while extending it with **multi-asset support** and **custom yield distribution** features.

## **Project Overview**

This project implements a **Multi-Token Vault** that integrates with **Aave V3** to provide yield generation across multiple ERC20 tokens. The vault supports both **custom yield distribution** using **Chainlink VRF** and **multi-asset management** with a unified interface.

## **Features Implemented**

### ✅ **1. Vault Core**

- **Deposit/Withdraw**: Users can deposit and withdraw at any time
- **Principal Protection**: Principal is always withdrawable (1:1 ratio maintained)
- **Yield Accumulation**: Yield generated from Aave remains in vault until harvested
- **Admin Control**: Only admin can harvest accumulated yield

### ✅ **2. Aave Integration**

- **Protocol**: Integrated with Aave V3 on Ethereum Mainnet
- **Tested Assets**: DAI and USDC
- **Yield Generation**: Real yield accrual through aToken balances
- **Testing**: Demonstrated on mainnet fork environment

### ✅ **3. Custom Yield Distribution (VRF)**

- **Random Selection**: Uses Chainlink VRF for fair winner selection
- **Configurable**: Admin can set yield amount and winner count
- **Transparency**: All requests and distributions are trackable

### ✅ **4. Multi-Token Support**

- **Unified Interface**: Single vault for multiple ERC20 tokens
- **Configurable**: Admin can add/remove supported assets
- **Cross-Asset Withdrawals**: Users can withdraw in any supported token
- **Swap Integration**: Automatic token swapping via MockDEX

## **Architecture**

### **Core Contracts**

1. **MultiTokenVault.sol** - Main vault contract with ERC4626 compliance and VRF integration
2. **MultiTokenVaultStorage.sol** - Storage layout for upgradeability and state management
3. **MockDEX.sol** - Mock DEX for cross-asset swaps and testing

### **Contract Details**

#### **MultiTokenVault.sol**

- **Purpose**: Main vault implementation with multi-asset support
- **Features**:
  - ERC4626 standard compliance
  - Aave V3 integration for yield generation
  - Chainlink VRF for random yield distribution
  - Cross-asset deposit/withdrawal functionality
  - Admin controls for yield harvesting
- **Size**: 731 lines, 30KB

#### **MultiTokenVaultStorage.sol**

- **Purpose**: Storage layout for upgradeable vault
- **Features**:
  - Multi-asset mappings and arrays
  - Fee management per asset
  - USD value tracking
  - VRF state variables
  - MockDEX integration
- **Size**: 44 lines, 1.3KB

#### **MockDEX.sol**

- **Purpose**: Custom mock decentralized exchange for DAI/USDC swaps
- **Features**:
  - DAI/USDC swap functionality (primary use case)
  - Configurable exchange rates (1:1 default)
  - Quote and swap functions
  - Event logging for transactions
  - Decimal handling (DAI: 18 decimals, USDC: 6 decimals)
- **Size**: 115 lines, 4.0KB

### **Key Features**

- **ERC4626 Compliance**: Standard vault interface
- **Aave V3 Integration**: Real yield generation through aToken balances
- **VRF Integration**: Built-in Chainlink VRF for fair random yield distribution
- **Multi-Asset Support**: Unified interface for multiple ERC20 tokens
- **Admin Controls**: Secure yield harvesting and asset management
- **Cross-Asset Swaps**: Flexible withdrawal options via MockDEX

## **Deployment**

### **Network**

- **Ethereum Mainnet Fork** (for testing)
- **Aave V3 Integration** for yield generation

### **Supported Assets**

- **DAI** (18 decimals)
- **USDC** (6 decimals)

### **VRF Configuration**

- **Chainlink VRF V2 Plus** integration
- **Callback Gas Limit**: 100,000
- **Request Confirmations**: 3

## **Usage**

### **For Users**

```solidity
// Deposit tokens
vault.depositMulti(DAI, 1000e18, user);

// Withdraw in same token
vault.withdrawMulti(DAI, shares, user, user);

// Withdraw in different token (triggers swap)
vault.withdrawMulti(USDC, shares, user, user);
```

### **For Admin**

```solidity
// Add new supported asset
vault.addSupportedAsset(WETH);

// Harvest accumulated yield
vault.harvestYield(DAI);

// Request random yield distribution
vault.requestRandomYieldDistribution(
    1000e18, // 1000 DAI yield
    3,       // 3 winners
    DAI,     // Distribute in DAI
    true     // Pay with ETH
);
```

## **Testing**

### **Test Coverage**

- ✅ **Deposits**: Multi-asset deposit functionality (DAI/USDC tested)
- ✅ **Withdrawals**: Direct and cross-asset withdrawals (DAI↔USDC swaps)
- ✅ **Yield Accrual**: Real yield generation through Aave
- ✅ **Admin Harvest**: Yield extraction by admin
- ✅ **VRF Integration**: Random yield distribution
- ✅ **MockDEX Testing**: DAI/USDC swap functionality
- ✅ **Edge Cases**: Swap failures, insufficient liquidity
- ✅ **Math Verification**: Correct yield distribution

### **Test Files**

- `test/MultiAssetVaultCoreTest.t.sol` - Core functionality tests
- `test/VRFIntegrationTest.t.sol` - VRF integration tests
- `script/FinalComprehensiveTest.s.sol` - End-to-end testing

### **Running Tests**

```bash
# Run all tests
forge test

# Run specific test
forge test --match-test testSwapBasedWithdrawals

# Run on mainnet fork
forge test --fork-url https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY
```

## **Yield Logic**

### **Yield Generation**

1. **Deposit**: User deposits ERC20 tokens
2. **Aave Supply**: Tokens are supplied to Aave V3
3. **aToken Accrual**: Yield accumulates in aToken balances
4. **Tracking**: Vault tracks accumulated yield per asset
5. **Harvest**: Admin can harvest yield to any supported asset

### **Yield Distribution**

1. **VRF Request**: Admin requests random distribution
2. **Winner Selection**: VRF selects random winners
3. **Distribution**: Yield is distributed to selected winners
4. **Transparency**: All distributions are logged and trackable

## **Protocol Integration Choices**

### **Aave V3 Selection**

- **Reason**: Most established lending protocol with high TVL
- **Benefits**: Real yield generation, battle-tested security
- **Integration**: Direct aToken balance tracking

### **Chainlink VRF Selection**

- **Reason**: Industry standard for verifiable randomness
- **Benefits**: Fair distribution, tamper-proof
- **Implementation**: VRF V2 Plus with wrapper pattern

### **Multi-Asset Architecture**

- **Reason**: Unified interface for better UX
- **Benefits**: Single vault for multiple tokens, cross-asset withdrawals
- **Implementation**: ERC4626 standard with asset mapping

## **Security Considerations**

- **Access Control**: Only admin can harvest yield
- **Principal Protection**: 1:1 withdrawal ratio maintained
- **VRF Security**: Uses Chainlink's proven randomness
- **Aave Integration**: Leverages Aave's security model
- **Upgradeability**: Storage separation for future upgrades

## **Assumptions**

1. **Aave V3**: Assumes Aave V3 is available and functional
2. **VRF Availability**: Assumes Chainlink VRF is operational
3. **Token Standards**: All tokens follow ERC20 standard
4. **Gas Costs**: VRF requests require sufficient gas
5. **Liquidity**: MockDEX has sufficient liquidity for swaps

## **Getting Started**

1. **Clone Repository**

   ```bash
   git clone https://github.com/atkosX/aave-vault.git
   cd aave-vault
   ```

2. **Install Dependencies**

   ```bash
   forge install
   ```

3. **Run Tests**

   ```bash
   forge test
   ```

4. **Deploy to Fork**
   ```bash
   anvil --fork-url https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY
   forge script script/DeployMultiTokenVault.s.sol --rpc-url http://localhost:8545 --broadcast
   ```

## **License**

MIT License - See LICENSE file for details

---

**Note**: This project demonstrates advanced DeFi concepts including multi-asset vaults, yield generation, and verifiable randomness. All code has been tested on mainnet fork and includes comprehensive test coverage.
