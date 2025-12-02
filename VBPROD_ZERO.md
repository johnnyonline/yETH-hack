# vb_prod → 0 issue (quick note)

## What happens
- Two trigger paths to `vb_prod = 0`:
  - **Multi-step path (attack POC)**: Imbalanced adds/withdraws shrink `vb_prod` to tiny (~3.53e15). `_calc_supply` then overshoots (sp0 ≈ 1.09e22), collapses (sp1 ≈ 4.42e17), and `r = r * sp / s` truncates to 0.
  - **Single-call path**: One huge, weight-balanced add makes `_pow_up` return 0 for an asset; `vb_prod_final` becomes 0 before `_calc_supply` runs.

## How to validate
1) Run the diagnostic test that rebuilds the attack state and shows the zeroing step:
   ```
   forge test -vv --match-test test_calc_supply_zeroes_small_prod
   ```
   - It asserts pow-up leaves `vb_prod` ≈ `3_527_551_366_992_573` (non-zero).
   - It calls `debug_calc_supply_two_iters` and checks:
     - After iteration 1: `sp0 ≈ 1.09e22`, `r0 > 0`.
     - After iteration 2: `sp1 ≈ 4.42e17`, `r1 == 0` (truncated in `_calc_supply`).

2) If you want to see the raw helpers:
   - `debug_vb_prod_step` mirrors the pow-up update per asset (shows the small-but-nonzero product).
   - `debug_calc_supply_two_iters` runs the first two `_calc_supply` iterations and returns `(sp0, r0, sp1, r1)`.

Files involved: `src/Pool.vy` (debug helpers), `test/VbProdAnalysis.t.sol` (diagnostic test), `test/interfaces/IPool.sol` (exposes helpers).***

## Why this state is reachable (pre-fifth add, multi-step path)
- Bands are effectively disabled (constructor sets lower/upper to `PRECISION`, which unpacks to limits > weight), so extreme imbalance is allowed.
- Repeated balanced `remove_liquidity` calls shrink all vbs, especially already-small assets (3, 6, 7).
- Adds before the 5th call top up only 0/1/2/4/5; assets 3/6/7 stay tiny.
- Just before the 5th add, vbs are:  
  0: 6.849e20, 1: 6.849e20, 2: 4.104e20, 3: 3.53e18, 4: 4.104e20, 5: 5.491e20, 6: 6.56e17, 7: 6.30e17; supply ≈ 2.514e21.
- The 5th add dumps ~1.6–2.7e21 into 0/1/2/4/5 (≈4x on several). `prev_vb/vb ≈ 0.25`, `wn` = 1.6, 1.6, 0.8, 0.8, 2.0. Pow-up multipliers: ~0.11, 0.11, 0.33, 0.33, 0.063 → vb_prod from 4.22e19 → ~3.53e15 (non-zero).
- `_calc_supply` then zeroes `vb_prod` in the second iteration (sp0 ≈ 1.09e22 → sp1 ≈ 4.42e17; `r` truncates to 0).

## Per-asset contributions (from real logs)
- POC 5th add (multi-step path), `DebugAddLiquidityAsset` events:
  - asset0 pow_up ≈ 0.1099e18 → vb_prod_after 4.64e18
  - asset1 pow_up ≈ 0.1099e18 → vb_prod_after 5.10e17
  - asset2 pow_up ≈ 0.3314e18 → vb_prod_after 1.69e17
  - asset4 pow_up ≈ 0.3314e18 → vb_prod_after 5.60e16
  - asset5 pow_up ≈ 0.0630e18 → vb_prod_after 3.53e15 (small-but-nonzero before `_calc_supply`)
  - assets 3/6/7 skipped (zero deposit)
- Single-call huge balanced add, `DebugAddLiquidityAsset` events:
  - asset0 pow_up 3.58e14 → vb_prod_after 4.36e14
  - asset1 1.58e14 → 6.90e10
  - asset2 1.25e16 → 8.65e8
  - asset3 1.66e16 → 1.44e7
  - asset4 1.33e16 → 1.92e5
  - asset5 4.53e13 → 8
  - asset6 3.39e17 → 2
  - asset7 3.36e17 → **0** (vb_prod hits zero in pow-up loop)
