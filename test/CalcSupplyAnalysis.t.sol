// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";

/**
 * @title CalcSupplyAnalysis
 * @notice Simulates the _calc_supply function to show WHERE vb_prod becomes 0
 *
 * The _calc_supply function has this iteration:
 *   1. sp = (l - s * r) / d
 *   2. For each asset: r = r * sp / s  (8 times for 8 assets)
 *   3. Check convergence, repeat
 *
 * When sp < s repeatedly, r gets multiplied by (sp/s)^8 each iteration,
 * which can cause it to underflow to 0.
 */
contract CalcSupplyAnalysisTest is Test {
    uint256 constant PRECISION = 1e18;
    uint256 constant MAX_POW_REL_ERR = 100; // 1e-16

    /**
     * @notice Simulate _calc_supply with the values just before vb_prod becomes 0
     *
     * From the trace:
     *   vb_prod BEFORE 5th add: 42219827707740669313 (~42.2e18)
     *   vb_sum changes from ~2.7e21 to ~10.9e21
     *   supply changes correspondingly
     */
    function test_simulate_calc_supply() public pure {
        console.log("=== SIMULATING _calc_supply ===");
        console.log("");
        console.log("This simulates what happens inside _calc_supply when vb_prod becomes 0");
        console.log("");

        // These are approximate values at the critical moment
        // The vb_prod input is high (~42e18) but gets destroyed inside _calc_supply
        uint256 num_assets = 8;
        uint256 amplification = 450e18;  // A * f^n
        uint256 vb_prod_input = 42219827707740669313;  // ~42.2e18, BEFORE add
        uint256 vb_sum_input = 10903169054856814420725; // ~10.9e21, AFTER add (larger due to liquidity added)
        uint256 supply_input = 2744650073551609343038; // ~2.7e21, supply before this add

        console.log("INPUT VALUES:");
        console.log("  num_assets:", num_assets);
        console.log("  amplification:", amplification);
        console.log("  vb_prod (r):", vb_prod_input);
        console.log("  vb_sum:", vb_sum_input);
        console.log("  supply (s):", supply_input);
        console.log("");

        // Calculate initial values
        uint256 l = amplification * vb_sum_input;  // A * sigma
        uint256 d = amplification - PRECISION;      // A - 1
        uint256 s = supply_input;                   // D[m]
        uint256 r = vb_prod_input;                  // pi[m]

        console.log("DERIVED VALUES:");
        console.log("  l (A * vb_sum):", l);
        console.log("  d (A - 1):", d);
        console.log("");

        console.log("=== ITERATION TRACE ===");

        for (uint256 iter = 0; iter < 10; iter++) {
            console.log("");
            console.log("--- Iteration", iter, "---");
            console.log("  s (supply estimate):", s);
            console.log("  r (vb_prod):", r);

            // Check for potential overflow in s * r
            uint256 sr = s * r;
            console.log("  s * r:", sr);

            if (sr > l) {
                console.log("  WARNING: s * r > l, would underflow in (l - s*r)!");
                console.log("  This is where safe math would revert.");
                break;
            }

            // sp = (l - s * r) / d
            uint256 sp = (l - sr) / d;
            console.log("  sp (new supply):", sp);
            console.log("  sp/s ratio:", sp * PRECISION / s);

            // Update r: for each asset, r = r * sp / s
            uint256 r_before = r;
            for (uint256 i = 0; i < num_assets; i++) {
                r = (r * sp) / s;
            }
            console.log("  r after update:", r);
            console.log("  r shrinkage factor:", r * PRECISION / r_before);

            if (r == 0) {
                console.log("");
                console.log(">>> r (vb_prod) HAS BECOME 0! <<<");
                console.log("");
                console.log("EXPLANATION:");
                console.log("  r = r * (sp/s)^8");
                console.log("  When sp < s, each multiplication shrinks r");
                console.log("  With 8 assets, the factor is (sp/s)^8");
                console.log("  Eventually r underflows to 0 due to integer division");
                break;
            }

            // Check convergence
            uint256 delta;
            if (sp >= s) {
                delta = sp - s;
            } else {
                delta = s - sp;
            }

            if ((delta * PRECISION) / s <= MAX_POW_REL_ERR) {
                console.log("  Converged! delta:", delta);
                console.log("");
                console.log("FINAL VALUES:");
                console.log("  supply:", sp);
                console.log("  vb_prod:", r);
                break;
            }

            s = sp;
        }
    }

    /**
     * @notice Show the mathematical relationship
     */
    function test_math_explanation() public pure {
        console.log("=== WHY vb_prod BECOMES 0 IN _calc_supply ===");
        console.log("");
        console.log("The _calc_supply iteration does:");
        console.log("  1. sp = (A * vb_sum - s * r) / (A - 1)");
        console.log("  2. r = r * (sp/s)^n  where n = num_assets = 8");
        console.log("  3. Repeat until converged");
        console.log("");
        console.log("KEY INSIGHT:");
        console.log("  When vb_sum increases significantly (adding liquidity),");
        console.log("  the new supply sp will be MUCH LARGER than old supply s.");
        console.log("");
        console.log("  BUT WAIT - that would make sp/s > 1, increasing r!");
        console.log("");
        console.log("  The issue is more subtle:");
        console.log("  - The INPUT vb_prod is calculated BEFORE _calc_supply");
        console.log("  - It uses incremental update: vb_prod *= (prev_vb/vb)^wn");
        console.log("  - When adding lots of liquidity to some assets,");
        console.log("    prev_vb/vb becomes very small for those assets");
        console.log("  - The product of many small factors approaches 0");
        console.log("");
        console.log("  Then inside _calc_supply:");
        console.log("  - The iteration further modifies r");
        console.log("  - With an already-small r and certain s/sp ratios,");
        console.log("    r can round down to 0");
    }

    /**
     * @notice Demonstrate the incremental vb_prod update underflow
     */
    function test_incremental_underflow() public pure {
        console.log("=== INCREMENTAL vb_prod UPDATE (line 474) ===");
        console.log("");
        console.log("Formula: vb_prod = vb_prod * (prev_vb * 1e18 / vb)^wn / 1e18");
        console.log("");
        console.log("At the 5th add_liquidity, looking at asset 0 (sfrxETH, weight=20%):");
        console.log("");

        uint256 prev_vb = 684908434204245837382;  // ~684e18
        uint256 added = 1784169320136805803209;   // ~1784e18
        uint256 vb = prev_vb + added;              // ~2469e18
        uint256 weight = 200000000000000000;       // 0.2 (20%)
        uint256 num_assets = 8;
        uint256 wn = weight * num_assets / PRECISION;  // 1.6

        console.log("  prev_vb:", prev_vb);
        console.log("  amount added:", added);
        console.log("  vb (new):", vb);
        console.log("");

        uint256 ratio = prev_vb * PRECISION / vb;
        console.log("  ratio (prev_vb/vb):", ratio);
        console.log("  This is", ratio * 100 / PRECISION, "% (less than 100%)");
        console.log("");
        console.log("  weight:", weight);
        console.log("  wn (weight * 8):", weight * num_assets);
        console.log("");

        // Simulate (ratio)^wn
        // For simplicity, approximate: 0.277^1.6 = ~0.12
        console.log("  Approximate (ratio)^1.6 = ~0.12");
        console.log("");
        console.log("  This means just for asset 0, vb_prod is multiplied by ~0.12");
        console.log("  With similar ratios for assets 1,2,4,5, the cumulative effect");
        console.log("  can reduce vb_prod to near-zero.");
        console.log("");
        console.log("  The _pow_up function uses fixed-point math that can round to 0");
        console.log("  when the result is extremely small.");
    }
}
