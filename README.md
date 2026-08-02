# CodesenSys Enterprise OP Stack Reference Architecture

An open-source consortium-style Ethereum Layer 2 demonstration for enterprise workflows.
The repository contains two independent Solidity applications intended for deployment on
the same persistent OP Stack L2:

- supply-chain provenance and custody checkpoints
- patient-controlled access governance for encrypted off-chain health records

## Permissioning model

OP Stack does not provide a native transaction-allowlist precompile by default. This
reference architecture combines:

1. RPC/network controls through a gateway such as `proxyd`
2. application authorization through OpenZeppelin `AccessControl`
3. multisig-oriented governance and operational key separation

A custom EVM-level allowlist is a future chain customization, not an implemented feature.

## Local validation

```bash
forge install OpenZeppelin/openzeppelin-contracts --no-commit
forge fmt --check
forge build
forge test -vvv
forge coverage
forge snapshot
```

See `SPRINT_INSTRUCTIONS_UPDATED.md` in the project delivery package for the complete
execution plan.
