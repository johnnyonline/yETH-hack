// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IPool} from "./interfaces/IPool.sol";
import {IOETH} from "./interfaces/IOETH.sol";
import "forge-std/Test.sol";
import "forge-std/StdInvariant.sol";

/// @title PoolHandler - Generic fuzz handler for yETH Pool
contract PoolHandler is Test {
    IPool public immutable pool;
    IERC20 public immutable yeth;
    IOETH public constant oeth = IOETH(0x39254033945AA2E4809Cc2977E7087BEE48bd7Ab);
    address[] public assets;
    uint256 public numAssets;
    
    uint256 public ghost_totalDeposited;
    uint256 public ghost_totalExtracted;
    
    constructor(IPool _pool, IERC20 _yeth, uint256 _numAssets) {
        pool = _pool;
        yeth = _yeth;
        numAssets = _numAssets;
        
        for (uint256 i = 0; i < _numAssets; i++) {
            assets.push(_pool.assets(i));
        }
    }
    
    function addLiquidity(uint256[8] calldata amounts) external {
        uint256[] memory depositAmounts = new uint256[](numAssets);
        uint256 totalDeposit = 0;
        
        for (uint256 i = 0; i < numAssets; i++) {
            uint256 amount = bound(amounts[i], 0, 2000e18);
            depositAmounts[i] = amount;
            if (amount > 0) {
                deal(assets[i], address(this), amount);
                IERC20(assets[i]).approve(address(pool), amount);
                totalDeposit += amount;
            }
        }
        
        if (totalDeposit == 0) return;
        
        try pool.add_liquidity(depositAmounts, 0, address(this)) {
            ghost_totalDeposited += totalDeposit;
        } catch {}
    }
    
    function removeLiquidity(uint256 amount) external {
        uint256 supply = pool.supply();
        if (supply == 0) return;
        
        amount = bound(amount, 1e17, supply);
        
        uint256[] memory balancesBefore = new uint256[](numAssets);
        for (uint256 i = 0; i < numAssets; i++) {
            balancesBefore[i] = IERC20(assets[i]).balanceOf(address(this));
        }
        
        deal(address(yeth), address(this), amount);
        yeth.approve(address(pool), amount);
        
        uint256[] memory minAmounts = new uint256[](numAssets);
        try pool.remove_liquidity(amount, minAmounts, address(this)) {
            for (uint256 i = 0; i < numAssets; i++) {
                uint256 balanceAfter = IERC20(assets[i]).balanceOf(address(this));
                if (balanceAfter > balancesBefore[i]) {
                    ghost_totalExtracted += balanceAfter - balancesBefore[i];
                }
            }
        } catch {}
    }
    
    function updateRates(uint256[8] calldata indices) external {
        uint256[] memory rateIndices = new uint256[](numAssets);
        for (uint256 i = 0; i < numAssets; i++) {
            rateIndices[i] = bound(indices[i], 0, numAssets - 1);
        }
        
        try pool.update_rates(rateIndices) {} catch {}
    }
    
    function triggerRebase() external {
        try oeth.rebase() {} catch {}
    }
}

/// @title InvariantHackTest - Invariant tests for yETH Pool
contract InvariantHackTest is StdInvariant, Test {
    IPool public constant POOL = IPool(0xCcd04073f4BdC4510927ea9Ba350875C3c65BF81);
    IERC20 public constant YETH = IERC20(0x1BED97CBC3c24A4fb5C069C6E311a967386131f7);
    
    PoolHandler public handler;
    
    function setUp() public {
        uint256 blockNumber = 23914085;
        vm.selectFork(vm.createFork(vm.envString("ETH_RPC_URL"), blockNumber));
        
        handler = new PoolHandler(POOL, YETH, 8);
        
        targetContract(address(handler));
        excludeContract(address(POOL));
    }
    
    function invariant_noFreeValue() public view {
        uint256 deposited = handler.ghost_totalDeposited();
        uint256 extracted = handler.ghost_totalExtracted();
        
        if (deposited > 0) {
            assertLe(extracted, deposited * 11 / 10, "EXPLOIT: Extracted > Deposited");
        }
    }
    
    function invariant_poolHealth() public view {
        uint256 supply = POOL.supply();
        (uint256 vbProd, uint256 vbSum) = POOL.vb_prod_sum();
        
        if (supply > 0) {
            assertGt(vbProd, 0, "vb_prod is zero");
            assertGt(vbSum, 0, "vb_sum is zero");
        }
    }
}
