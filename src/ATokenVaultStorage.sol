// SPDX-License-Identifier: UNLICENSED
// All Rights Reserved © AaveCo

pragma solidity ^0.8.26;

/**
 * @title ATokenVaultStorage
 * @author Aave Protocol
 * @notice Contains storage variables for the ATokenVault.
 */
abstract contract ATokenVaultStorage {
    mapping(address => uint256) internal _sigNonces;

    struct Storage {
        // total aToken incl. fees
        uint128 lastVaultBalance;
        // fees accrued since last updated
        uint128 accumulatedFees;
        // Deprecated storage gap
        uint40 __deprecated_gap;
        // as a fraction of 1e18
        uint64 fee;
        // Reserved storage space to allow for layout changes in the future
        uint256[50] __gap;
    }

    Storage internal _s;

    // VRF v2.5 Direct Funding storage
    address internal s_vrfWrapper;
    uint32 internal s_callbackGasLimit;
    uint16 internal s_requestConfirmations;
    uint32 internal s_numWords;
    
    // Lottery yield storage
    uint128 internal s_accruedYieldForLottery;
    
    // Participant management
    address[] internal s_eligibleParticipants;
    mapping(address => bool) internal s_isParticipantEligible;
    mapping(address => uint256) internal s_participantIndex;
    
    // Lottery context for each VRF request
    struct LotteryContext {
        uint256 yieldAmount;
        address[] participants;
        uint256 timestamp;
        bool isFulfilled;
    }
    
    mapping(uint256 => LotteryContext) internal s_lotteryContext;
    
    // Distribution configuration
    struct DistributionConfig {
        bool isEnabled;
        uint256 distributionInterval;
        uint256 lastDistributionTime;
        uint256 minParticipants;
        uint256 maxWinners;
        uint256 lotteryYieldPercentage;
    }
    
    DistributionConfig internal s_distributionConfig;
}
