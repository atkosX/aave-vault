## **Objective**

Build a vault that allows users to **deposit ERC20 tokens**, **safely withdraw their principal**, and **generate yield** through a real protocol integration **Aave**.

All yield should be **trackable** and **fully extractable** by an admin or designated role.

## **Inspiration & Reference**

This project takes **reference and inspiration** from [Aave's ATokenVault](https://github.com/aave/Aave-Vault/blob/main/src/ATokenVault.sol) for the core vault functionality, while extending it with **multi-asset support** and **custom yield distribution** features.

## **Project Overview**

This project implements a **Multi-Token Vault** that integrates with **Aave V3** to provide yield generation across multiple ERC20 tokens. The vault supports both **custom yield distribution** using **Chainlink VRF** and **multi-asset management** with a unified interface.

## **Features Implemented**

### **1. Vault Core**

- **Deposit/Withdraw**: Users can deposit and withdraw at any time
- **Principal Protection**: Principal is always withdrawable (1:1 ratio maintained)
- **Yield Accumulation**: Yield generated from Aave remains in vault until harvested
- **Admin Control**: Only admin can harvest accumulated yield

### **2. Aave Integration**

- **Protocol**: Integrated with Aave V3 on Ethereum Mainnet
- **Tested Assets**: DAI and USDC
- **Yield Generation**: Real yield accrual through aToken balances
- **Testing**: Demonstrated on mainnet fork environment

### **3. Custom Yield Distribution (VRF)**

- **Random Selection**: Uses Chainlink VRF for fair winner selection
- **Configurable**: Admin can set yield amount and winner count
- **Transparency**: All requests and distributions are trackable

### **4. Multi-Token Support**

- **Unified Interface**: Single vault for multiple ERC20 tokens
- **Configurable**: Admin can add/remove supported assets
- **Cross-Asset Withdrawals**: Users can withdraw in any supported token
- **MockDEX Integration**: Custom DEX for seamless asset swapping
- **Unified Share System**: Common shares calculated based on USD value

## **Key Design Decisions**

### **MockDEX for Cross-Asset Withdrawals**

- **Purpose**: Created a custom MockDEX to enable depositors to withdraw any supported asset
- **Functionality**: Handles DAI ↔ USDC swaps with 1:1 exchange rate
- **Integration**: Automatically triggered when vault lacks sufficient requested asset
- **Benefits**: Users can deposit DAI but withdraw USDC (or vice versa)

### **Unified Share System**

- **Common Shares**: All depositors receive the same share token (MTV) regardless of deposit asset
- **USD-Based Calculation**: Share value calculated using USD price oracle
- **Proportional Ownership**: Each share represents proportional ownership of total vault value
- **Cross-Asset Value**: Share value reflects combined value of all supported assets

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

#### **MultiTokenVaultStorage.sol**

- **Purpose**: Storage layout for upgradeable vault
- **Features**:
  - Multi-asset mappings and arrays
  - Fee management per asset
  - USD value tracking
  - VRF state variables
  - MockDEX integration

#### **MockDEX.sol**

- **Purpose**: Custom mock decentralized exchange for DAI/USDC swaps
- **Features**:
  - DAI/USDC swap functionality (primary use case)
  - Configurable exchange rates (1:1 default)
  - Quote and swap functions
  - Event logging for transactions
  - Decimal handling (DAI: 18 decimals, USDC: 6 decimals)

### **Key Features**

- **ERC4626 Compliance**: Standard vault interface
- **Aave V3 Integration**: Real yield generation through aToken balances
- **VRF Integration**: Built-in Chainlink VRF for fair random yield distribution
- **Multi-Asset Support**: Unified interface for multiple ERC20 tokens
- **Admin Controls**: Secure yield harvesting and asset management
- **Cross-Asset Swaps**: Flexible withdrawal options via MockDEX


## **Testing**

### **Test Coverage**

- **Deposits**: Multi-asset deposit functionality (DAI/USDC tested)
- **Withdrawals**: Direct and cross-asset withdrawals (DAI↔USDC swaps)
- **Yield Accrual**: Real yield generation through Aave
- **Admin Harvest**: Yield extraction by admin
- **VRF Integration**: Random yield distribution with mocked randomness
- **MockDEX Testing**: DAI/USDC swap functionality
- **Edge Cases**: Swap failures, insufficient liquidity
- **Math Verification**: Correct yield distribution

### **VRF Testing Approach**

- **Mocked Randomness**: For testing purposes, random numbers are mocked to ensure deterministic test results
- **Simulation**: Tests simulate the VRF callback process without requiring actual Chainlink VRF requests
- **Algorithm Verification**: Winner selection algorithm is tested with known random seeds
- **Production Ready**: In production, real Chainlink VRF provides cryptographically secure randomness


### **Running Tests**

```bash
# Run all tests
forge test

# Run specific test
forge test --match-test testSwapBasedWithdrawals

# Run on mainnet fork
forge test --fork-url https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY
```

## **Yield Logic & Aave Integration**

### **How aToken Deposits Generate Yield from Aave**

#### **1. Deposit Process**

```solidity
// User deposits 1000 DAI
vault.depositMulti(DAI, 1000e18, user);

// Vault automatically:
// 1. Transfers DAI from user to vault
// 2. Supplies DAI to Aave V3 Pool
// 3. Receives aDAI tokens in return
// 4. Mints MTV shares to user based on USD value
```

#### **2. Yield Accrual Mechanism**

- **aToken Balance Growth**: aDAI balance increases over time due to Aave's lending yield
- **Real Yield**: Not simulated - actual interest earned from Aave's lending pool
- **Automatic Compounding**: Yield is automatically reinvested in the aToken
- **Transparent Tracking**: Vault tracks aToken balance changes to measure yield

#### **3. Yield Calculation**

```solidity
// Yield = Current aToken Balance - Last Recorded Balance
uint256 newYield = currentATokenBalance - _lastVaultBalance[asset];

// Example:
// Initial: 1000 aDAI
// After 1 day: 1000.1 aDAI (0.1 DAI yield)
// Yield = 1000.1 - 1000 = 0.1 DAI
```

#### **4. Yield Distribution Options**

**Option A: Admin Harvest**

- Admin calls `harvestYield(asset)` to extract accumulated yield
- Yield is withdrawn from Aave and sent to admin
- Vault's aToken balance decreases by yield amount

**Option B: VRF Random Distribution**

- Admin calls `requestRandomYieldDistribution()`
- Chainlink VRF selects random winners from participants
- Yield is distributed directly to winners' addresses
- Creates a lottery system for yield distribution

### **Yield Generation Flow**

1. **User Deposit**: User deposits ERC20 tokens (DAI/USDC)
2. **Aave Supply**: Vault supplies tokens to Aave V3 lending pool
3. **aToken Receipt**: Vault receives aTokens (aDAI/aUSDC) representing deposit + yield
4. **Yield Accrual**: aToken balance increases over time due to Aave's lending interest
5. **Yield Tracking**: Vault monitors aToken balance changes to calculate yield
6. **Yield Distribution**: Admin can harvest or distribute yield via VRF lottery

## **Protocol Integration Choices**

### **Aave V3 Selection**

- **Reason**: Most established lending protocol with high TVL
- **Benefits**: Real yield generation, battle-tested security
- **Integration**: Direct aToken balance tracking


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

## **Assumptions & Design Decisions**

### **Technical Assumptions**

1. **Aave V3 Availability**: Aave V3 protocol is operational and accessible on target network
2. **Chainlink VRF**: VRF service is available and functioning for random number generation
3. **Token Standards**: All supported tokens follow ERC20 standard with standard decimal places
4. **Price Oracle**: Aave's price oracle provides accurate USD pricing for supported assets
5. **Gas Availability**: Sufficient gas for VRF requests and complex operations
6. **Network Stability**: Ethereum mainnet (or fork) is stable and accessible

### **Economic Assumptions**

1. **Yield Rates**: Aave lending rates remain positive and sustainable
2. **Liquidity**: MockDEX maintains sufficient liquidity for cross-asset swaps
3. **Price Stability**: USD prices remain relatively stable during vault operations
4. **User Behavior**: Users understand the unified share system and cross-asset withdrawals
5. **Admin Trust**: Vault admin acts in good faith for yield harvesting and distribution


### **Design Decisions**

1. **Unified Shares**: Chose single share token (MTV) for simplicity and cross-asset compatibility
2. **USD Pricing**: Used USD as base currency for share calculations to handle multiple assets
3. **MockDEX**: Created custom DEX for testing rather than integrating with real DEX (Uniswap)
4. **VRF Integration**: Implemented VRF for fair random distribution rather than deterministic rules
5. **Aave Integration**: Chose Aave over other protocols for its maturity and security track record

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
