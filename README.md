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

Test:
```shell
forge t --mt test_attack -vv
```
