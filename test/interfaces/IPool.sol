// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface IPool {
    function virtual_balance(uint256 index) external view returns (uint256);

    function supply() external view returns (uint256);

    function num_assets() external view returns (uint256);
    
    function remove_liquidity(
        uint256 _lp_amount,
        uint256[] calldata _min_amounts,
        address _receiver
    ) external;

    function rate(uint256 index) external view returns (uint256);

    function packed_weight(uint256 index) external view returns (uint256);

    function debug_vb_prod_before_calc() external view returns (uint256);
    function debug_vb_sum_before_calc() external view returns (uint256);

    function vb_prod_sum() external view returns (uint256, uint256);

    function assets(uint256 index) external view returns (address);

    function add_liquidity(
        uint256[] calldata _amounts,
        uint256 _min_lp_amount,
        address _receiver
    ) external returns (uint256);

    function update_rates(uint256[] calldata _assets) external;

    function debug_calc_supply(uint256 _supply, uint256 _vb_prod, uint256 _vb_sum, bool _up) external view returns (uint256, uint256);

    function debug_calc_supply_two_iters(uint256 _supply, uint256 _vb_prod, uint256 _vb_sum) external view returns (uint256, uint256, uint256, uint256);

    function debug_vb_prod_step(uint256 _prev_vb, uint256 _new_vb, uint256 _packed_weight, uint256 _prod, uint256 _num_assets) external view returns (uint256);
}
