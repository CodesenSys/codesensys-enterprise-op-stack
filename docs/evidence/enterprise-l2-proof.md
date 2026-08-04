# Enterprise Contracts on CodesenSys OP Stack L2

## Network

- Network: CodesenSys OP Stack L2
- Chain ID: `3399647`
- Settlement layer: Ethereum Sepolia
- Local RPC: `http://127.0.0.1:8545`
- Deployer: `0xA8fc0E1E3Ad1E47B707a549C94Ec5989e75F3Cb5`

## Deployed contracts

### HealthRecordAccessControl

- Address: `0x4E949Ac98442Ec2F127e61b74C24837227Aac0f0`
- Deployment transaction: `0x6ddd0876b0a1673796a266720d5ba63c503652e2a2eb0a2954622f4cb3fc216e`
- Deployment block: `43326`
- Gas used: `961510`

### SupplyChainProvenance

- Address: `0x75AcB6eA506f5bDA66e2242dbd0139c78768193f`
- Deployment transaction: `0xdd0036fe4080daaa9fdcf0e507d3797d4eb294733cdc9c292b73bd5f54c0b691`
- Deployment block: `43458`
- Gas used: `1373906`

## Healthcare workflow

The healthcare contract demonstrated patient-controlled access to an encrypted off-chain record pointer.

### Lifecycle

```text
Provider role granted
        ↓
Record registered
        ↓
Time-boxed access granted
        ↓
Access assertion succeeded
        ↓
Emergency access logged
        ↓
Access revoked
        ↓
Access assertion reverted
```

### Evidence

- Record ID: `0xf9db27273db0f0c8bd3c90f66944921e3454860d19136a9afd8127c2cb11952d`
- Provider role transaction: `0xee431c963bf583a68599dd217b476b658958dcdba7cfddc50c8ebb6824157f12`
- Record registration transaction: `0x112ba100dea2f2415e7b655594f12e5406924b6ea54f1495794145426c02847c`
- Access grant transaction: `0x992bd503e2dbe6d6818c036494b26fc4ebfef35488825c1f801555643f6955b0`
- Emergency access transaction: `0x1294e61fa746db545c9bf4f7572701855a4e0392850df1120d0bb67b7303fc5b`
- Revocation transaction: `0x2ec60fab25dfd761687f5fefee65e7c4d19481738e72b18ab470cb24b5937e01`

The final access check reverted after revocation, proving that inactive grants are enforced on-chain.

## Supply-chain workflow

The supply-chain contract demonstrated role-gated provenance across the complete asset lifecycle.

### Lifecycle

```text
Manufactured
      ↓
InTransit
      ↓
CustomsCleared
      ↓
Received
      ↓
Recalled
```

### Evidence

- Asset ID: `0x5e780a6cf17af07cbdf5592c1fb66e175bd33e4f58678730fcbcaa00d1c49009`
- Registration transaction: `0x8f47571fee19615fd27ed599c320842ff4adf05f403a1603b8a1dd1450330541`
- In-transit transaction: `0xfdbac83c875c679445d4a04fe713acafc6e5be66cb2b36448e289a74eb6cb958`
- Customs-cleared transaction: `0x98f325e17ec15ed2813ee91e30a9ec2c53a150a3c3a0680422b52cb4dfc0d767`
- Received transaction: `0x50d71659257c8482fd89015810a366960c7cce6aa138c06898359808bc1bf035`
- Recall transaction: `0x4a965958db28e18578c9b16df329ea030cc33bd5b7d55d97ac98b11e899cb398`

The on-chain history returned five ordered checkpoints with stage, recorder, timestamp, evidence hash, and location.

## Cost

| Metric | Value |
|---|---:|
| Initial L2 balance | `0.050000000000000000 ETH` |
| Remaining L2 balance | `0.049999471021784100 ETH` |
| Total consumed | `0.000000528978215900 ETH` |

This covered:

- two contract deployments;
- healthcare role and record operations;
- access grant, emergency audit, and revocation;
- four supply-chain role assignments;
- asset registration;
- three stage transitions;
- product recall.

## End-to-end architecture

```text
Enterprise Application
        ↓
Smart Contracts
        ↓
CodesenSys OP Stack L2
        ↓
op-reth execution engine
        ↓
op-node sequencing and derivation
        ↓
op-batcher data publication
        ↓
Ethereum Sepolia
```

This demonstrates the complete lifecycle from enterprise application logic through custom L2 execution and Ethereum settlement infrastructure.
