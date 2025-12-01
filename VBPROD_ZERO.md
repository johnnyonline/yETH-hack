# vb_prod → 0 issue (quick note)

## What happens
- Imbalanced `add_liquidity` makes some assets jump ~4x while others stay near zero.
- The per-asset pow-up updates shrink `vb_prod` to a tiny but **non-zero** value (~3.5e15).
- In `_calc_supply`, the first iteration overshoots supply (sp0 ≈ 1.09e22), the second iteration collapses it (sp1 ≈ 4.42e17), and the repeated `r = r * sp / s` multiplies by a tiny ratio eight times, truncating `r` to **0**. This is where zero originates (not in the pow-up line).

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

## Why this state is reachable (pre-fifth add)
- Bands are effectively disabled (constructor sets lower/upper to `PRECISION`, which unpacks to limits > weight), so extreme imbalance is allowed.
- Repeated cycles of balanced `remove_liquidity` shrink **all** virtual balances, including already-small assets (3, 6, 7).
- Each `add_liquidity` before the 5th call deposits **zero** into assets 3/6/7, so they stay tiny while other assets get topped up.
- Just before the 5th add, vbs are:
  - 0: 6.849e20, 1: 6.849e20, 2: 4.104e20, 3: 3.53e18, 4: 4.104e20, 5: 5.491e20, 6: 6.56e17, 7: 6.30e17; supply ≈ 2.514e21.
- The 5th add dumps ~1.6–2.7e21 into assets 0/1/2/4/5 (≈4x on several). For those assets, `prev_vb / vb ≈ 0.25`, with `wn` of 1.6, 1.6, 0.8, 0.8, 2.0. The pow-up multipliers are ~0.11, 0.11, 0.33, 0.33, 0.063, so `vb_prod` is cut from 4.22e19 down to ~3.5e15 (still non-zero).
- `_calc_supply` then finishes the zeroing as described above.
