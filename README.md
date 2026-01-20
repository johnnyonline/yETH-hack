# yETH-hack

A proof of concept demonstrating an attack that occurred on yETH.

## The Vulnerability

The attack exploited unsafe math operations in [Pool.vy:1274](src/Pool.vy#L1274). The original code used `unsafe_div`, `unsafe_sub`, and `unsafe_mul` which bypass Vyper's built-in overflow/underflow checks.

**Fix**: Using safe math (standard arithmetic operators) instead of unsafe math causes the attack to revert. See the commented code in `src/Pool.vy` at line 1272-1276 and `test_attack` in `test/Hack.t.sol`.

## Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/johnnyonline/yETH-hack.git
   cd yETH-hack
   ```

2. **Set up virtual environment**
   ```bash
   uv venv
   source .venv/bin/activate  # On Windows: .venv\Scripts\activate
   deactivate  # To deactivate the venv
   ```

3. **Install dependencies**
   ```bash
   # Install all dependencies
   uv sync
   ```

   > Note: This project uses [uv](https://github.com/astral-sh/uv) for faster dependency installation. If you don't have uv installed, you can install it with `pip install uv` or follow the [installation instructions](https://github.com/astral-sh/uv#installation).

4. **Environment setup**
   ```bash
   cp .env.example .env
   # Edit .env with your API keys and configuration
   ```

## Usage

Build:
```shell
forge b
```

Test (replay attack):
```shell
forge t --mt test_attack -vv
```

## Invariant Testing

The invariant test in `test/InvariantHack.t.sol` uses generic handlers to fuzz the Pool and detect the exploit without prior knowledge of the attack pattern.

### Handlers

- `addLiquidity` - Deposit assets, receive yETH
- `removeLiquidity` - Burn yETH, extract assets
- `updateRates` - Update asset rates with fuzzed indices
- `triggerRebase` - Trigger OETH rebase

### Invariants

- `invariant_noFreeValue` - Cannot extract more value than deposited
- `invariant_poolHealth` - vb_prod and vb_sum remain valid when supply > 0

### Run Invariant Test

```shell
forge t --mt invariant -vv
```

### Results

The fuzzer discovers the exploit in just **2 calls**, extracting ~2587 ETH with only ~0.00005 ETH deposited:

```
[PASS] invariant_poolHealth() (runs: 3, calls: 300, reverts: 46)

╭-------------+-----------------+-------+---------+----------╮
| Contract    | Selector        | Calls | Reverts | Discards |
+============================================================+
| PoolHandler | addLiquidity    | 75    | 0       | 0        |
|-------------+-----------------+-------+---------+----------|
| PoolHandler | removeLiquidity | 62    | 46      | 0        |
|-------------+-----------------+-------+---------+----------|
| PoolHandler | triggerRebase   | 82    | 0       | 0        |
|-------------+-----------------+-------+---------+----------|
| PoolHandler | updateRates     | 81    | 0       | 0        |
╰-------------+-----------------+-------+---------+----------╯

Suite result: FAILED. 1 passed; 1 failed; 0 skipped; finished in 41.78s (47.45s CPU time)

Failing tests:
Encountered 1 failing test in test/InvariantHack.t.sol:InvariantHackTest
[FAIL: EXPLOIT: Extracted > Deposited: 2587307292531127467438 > 52617287]
        [Sequence] (original: 28, shrunk: 2)
                sender=0x45fDe635375a9680c34e501b43a82eB6c09C0952 addr=[test/InvariantHack.t.sol:PoolHandler]0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f calldata=removeLiquidity(uint256) args=[10791 [1.079e4]]
                sender=0xd5F7838F5C461fefF7FE49ea5ebaF7728bB0ADfa addr=[test/InvariantHack.t.sol:PoolHandler]0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f calldata=addLiquidity(uint256[8]) args=[[0, 23914085 [2.391e7], 11, 1, 767, 365, 23914085 [2.391e7], 4584]]
 invariant_noFreeValue() (runs: 1, calls: 100, reverts: 34)
```
