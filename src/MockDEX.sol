// SPDX-License-Identifier: UNLICENSED
// All Rights Reserved © AaveCo

pragma solidity ^0.8.26;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * @title MockDEX
 * @author Aave Protocol
 * @notice Simple mock DEX for USDC/DAI swaps for testing purposes
 */
contract MockDEX {
    // Exchange rates (18 decimals precision)
    mapping(address => mapping(address => uint256)) public exchangeRates;
    
    // Supported tokens
    address public immutable DAI;
    address public immutable USDC;
    
    event Swap(address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);
    
    constructor(address dai, address usdc) {
        DAI = dai;
        USDC = usdc;
        
        // Set initial exchange rate: 1 DAI = 1 USDC (1:1 for simplicity)
        exchangeRates[DAI][USDC] = 1e18;
        exchangeRates[USDC][DAI] = 1e18;
    }
    
    /**
     * @notice Set exchange rate between DAI and USDC
     * @param daiToUsdcRate Rate of DAI to USDC (18 decimals)
     */
    function setExchangeRate(uint256 daiToUsdcRate) external {
        require(daiToUsdcRate > 0, 'Invalid rate');
        
        exchangeRates[DAI][USDC] = daiToUsdcRate;
        exchangeRates[USDC][DAI] = 1e36 / daiToUsdcRate; // Inverse rate
    }
    
    /**
     * @notice Swap tokens
     * @param tokenIn Input token address
     * @param tokenOut Output token address  
     * @param amountIn Amount of input tokens
     * @return amountOut Amount of output tokens received
     */
    function swap(address tokenIn, address tokenOut, uint256 amountIn) external returns (uint256 amountOut) {
        require(tokenIn == DAI || tokenIn == USDC, 'Unsupported input token');
        require(tokenOut == DAI || tokenOut == USDC, 'Unsupported output token');
        require(tokenIn != tokenOut, 'Same token');
        require(amountIn > 0, 'Zero amount');
        
        uint256 rate = exchangeRates[tokenIn][tokenOut];
        require(rate > 0, 'Rate not set');
        
        // Calculate output amount
        amountOut = (amountIn * rate) / 1e18;
        
        // Handle USDC decimals (6 decimals vs 18 for DAI)
        if (tokenIn == USDC && tokenOut == DAI) {
            // USDC to DAI: adjust for decimal difference
            amountOut = amountOut * 1e12; // Convert from 6 to 18 decimals
        } else if (tokenIn == DAI && tokenOut == USDC) {
            // DAI to USDC: adjust for decimal difference  
            amountOut = amountOut / 1e12; // Convert from 18 to 6 decimals
        }
        
        // Transfer tokens
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).transfer(msg.sender, amountOut);
        
        emit Swap(tokenIn, tokenOut, amountIn, amountOut);
    }
    
    /**
     * @notice Get exchange rate between two tokens
     * @param tokenIn Input token
     * @param tokenOut Output token
     * @return rate Exchange rate (18 decimals)
     */
    function getExchangeRate(address tokenIn, address tokenOut) external view returns (uint256 rate) {
        return exchangeRates[tokenIn][tokenOut];
    }
    
    /**
     * @notice Get quote for swap
     * @param tokenIn Input token
     * @param tokenOut Output token
     * @param amountIn Input amount
     * @return amountOut Expected output amount
     */
    function getQuote(address tokenIn, address tokenOut, uint256 amountIn) external view returns (uint256 amountOut) {
        require(tokenIn == DAI || tokenIn == USDC, 'Unsupported input token');
        require(tokenOut == DAI || tokenOut == USDC, 'Unsupported output token');
        require(tokenIn != tokenOut, 'Same token');
        
        uint256 rate = exchangeRates[tokenIn][tokenOut];
        if (rate == 0) return 0;
        
        amountOut = (amountIn * rate) / 1e18;
        
        // Handle USDC decimals
        if (tokenIn == USDC && tokenOut == DAI) {
            amountOut = amountOut * 1e12;
        } else if (tokenIn == DAI && tokenOut == USDC) {
            amountOut = amountOut / 1e12;
        }
        
        return amountOut;
    }
}
