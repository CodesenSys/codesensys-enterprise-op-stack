# CodesenSys Enterprise OP Stack Applications

Enterprise reference applications for healthcare access governance and supply-chain provenance, deployed on a custom CodesenSys OP Stack Layer 2.

The repository demonstrates how role-based business logic, off-chain evidence, audit trails, and controlled state transitions can operate on dedicated enterprise L2 infrastructure.

Infrastructure repository:

https://github.com/CodesenSys/codesensys-op-stack-rollup

## Deployed network

| Property | Value |
|---|---|
| Network | CodesenSys OP Stack L2 |
| L2 chain ID | `3399647` |
| Settlement layer | Ethereum Sepolia |
| Execution client | `op-reth` |
| Rollup node | `op-node` |
| Native gas asset | ETH |

## Architecture

```text
             Healthcare Systems
                     │
                     ▼
       HealthRecordAccessControl
                     │
                     ├──────────────┐
                     │              │
                     │       Encrypted records
                     │       stored off-chain
                     │
                     ▼
              CodesenSys L2
                     ▲
                     │
                     │
        SupplyChainProvenance
                     ▲
                     │
              Supply-chain systems

                     │
                     ▼
           CodesenSys OP Stack
                     │
          ┌──────────┴──────────┐
          ▼                     ▼
      op-batcher            op-proposer
          │                     │
          └──────────┬──────────┘
                     ▼
              Ethereum Sepolia
```

## Applications

### HealthRecordAccessControl

Patient-controlled access governance for encrypted health records stored outside the blockchain.

The contract does not store protected health information on-chain. It stores:

- the patient address;
- a hash or content identifier for the encrypted record;
- the registration timestamp;
- provider access grants;
- grant expiry timestamps;
- access reason codes;
- emergency-access audit timestamps.

#### Roles

| Role | Responsibility |
|---|---|
| Patient | Registers records and grants or revokes provider access |
| Provider | Receives time-limited access to record pointers |
| Compliance | Logs emergency access events |
| Administrator | Manages credentialed roles |

#### Healthcare workflow

```text
Provider credentialed
        │
        ▼
Patient registers encrypted record pointer
        │
        ▼
Patient grants time-boxed provider access
        │
        ▼
Provider access is validated
        │
        ▼
Compliance emergency access is logged
        │
        ▼
Patient revokes access
        │
        ▼
Further access attempts revert
```

#### Privacy model

```text
On-chain
├── patient address
├── record identifier
├── encrypted storage reference
├── grant state
├── expiry timestamp
├── reason code
└── audit events

Off-chain
├── medical record contents
├── encryption keys
├── provider key exchange
└── regulated data storage
```

### SupplyChainProvenance

Role-gated supply-chain provenance with immutable checkpoint history and evidence hashes.

The contract records:

- asset registration;
- current lifecycle stage;
- authorized checkpoint recorder;
- checkpoint timestamp;
- evidence-document hash;
- location;
- recall status.

#### Roles

| Role | Responsibility |
|---|---|
| Manufacturer | Registers newly manufactured assets |
| Logistics | Records transit and customs checkpoints |
| Retailer | Records receipt at the destination |
| Auditor | Recalls an asset |

#### State machine

```text
Manufactured
     │
     ▼
InTransit
     │
     ├──────────────► Received
     │
     ▼
CustomsCleared
     │
     ▼
Received

Auditor
     │
     ▼
Recalled
```

Allowed transitions are enforced by the contract.

The complete provenance history remains available through `getHistory(assetId)`.

## Deployed contracts

| Contract | Address | Deployment block |
|---|---|---:|
| `HealthRecordAccessControl` | `0x4E949Ac98442Ec2F127e61b74C24837227Aac0f0` | `43326` |
| `SupplyChainProvenance` | `0x75AcB6eA506f5bDA66e2242dbd0139c78768193f` | `43458` |

Deployment metadata:

```text
deployments/enterprise-l2.json
```

Detailed evidence:

```text
docs/evidence/enterprise-l2-proof.md
```

## Verified healthcare execution

| Operation | Transaction |
|---|---|
| Provider role granted | `0xee431c963bf583a68599dd217b476b658958dcdba7cfddc50c8ebb6824157f12` |
| Record registered | `0x112ba100dea2f2415e7b655594f12e5406924b6ea54f1495794145426c02847c` |
| Access granted | `0x992bd503e2dbe6d6818c036494b26fc4ebfef35488825c1f801555643f6955b0` |
| Emergency access logged | `0x1294e61fa746db545c9bf4f7572701855a4e0392850df1120d0bb67b7303fc5b` |
| Access revoked | `0x2ec60fab25dfd761687f5fefee65e7c4d19481738e72b18ab470cb24b5937e01` |

The final access assertion reverted after revocation, confirming that inactive grants are enforced.

## Verified supply-chain execution

| Stage | Transaction |
|---|---|
| Manufactured | `0x8f47571fee19615fd27ed599c320842ff4adf05f403a1603b8a1dd1450330541` |
| InTransit | `0xfdbac83c875c679445d4a04fe713acafc6e5be66cb2b36448e289a74eb6cb958` |
| CustomsCleared | `0x98f325e17ec15ed2813ee91e30a9ec2c53a150a3c3a0680422b52cb4dfc0d767` |
| Received | `0x50d71659257c8482fd89015810a366960c7cce6aa138c06898359808bc1bf035` |
| Recalled | `0x4a965958db28e18578c9b16df329ea030cc33bd5b7d55d97ac98b11e899cb398` |

The decoded history returned five ordered checkpoints containing stage, recorder, timestamp, evidence hash, and location.

## L2 execution cost

| Metric | Value |
|---|---:|
| Initial L2 balance | `0.050000000000000000 ETH` |
| Remaining L2 balance | `0.049999471021784100 ETH` |
| Total consumed | `0.000000528978215900 ETH` |

This covered:

- two contract deployments;
- healthcare role assignment;
- record registration;
- access grant and revocation;
- emergency-access logging;
- four supply-chain role assignments;
- asset registration;
- three checkpoint transitions;
- product recall.

## Repository structure

```text
.
├── src/
│   ├── HealthRecordAccessControl.sol
│   └── SupplyChainProvenance.sol
├── script/
│   ├── DeployHealthAccess.s.sol
│   └── DeploySupplyChain.s.sol
├── test/
├── deployments/
│   └── enterprise-l2.json
├── docs/
│   └── evidence/
│       └── enterprise-l2-proof.md
├── foundry.toml
├── remappings.txt
└── README.md
```

## Development environment

The project uses Foundry and Solidity `0.8.24`.

Configuration includes:

- Solidity optimizer enabled;
- 20,000 optimizer runs;
- contract-specific gas reports;
- 1,000 fuzz runs;
- invariant testing;
- OpenZeppelin `AccessControl`.

## Install dependencies

```bash
forge install OpenZeppelin/openzeppelin-contracts --no-commit
```

## Build

```bash
forge build
```

## Test

```bash
forge test -vvv
```

## Coverage

```bash
forge coverage
```

## Gas snapshot

```bash
forge snapshot
```

## Deployment

Set the local L2 RPC:

```bash
export L2_RPC_URL=http://127.0.0.1:8545
```

Set the administrative address:

```bash
export ADMIN_ADDRESS=0xA8fc0E1E3Ad1E47B707a549C94Ec5989e75F3Cb5
```

Load the deployment key through a hidden prompt:

```bash
read -rs "PRIVATE_KEY?Enter deployment private key: "
echo
export PRIVATE_KEY
```

Verify the derived address before broadcasting:

```bash
cast wallet address --private-key "$PRIVATE_KEY"
```

Deploy healthcare access control:

```bash
forge script \
  script/DeployHealthAccess.s.sol:DeployHealthAccess \
  --rpc-url "$L2_RPC_URL" \
  --broadcast \
  -vvvv
```

Deploy supply-chain provenance:

```bash
forge script \
  script/DeploySupplyChain.s.sol:DeploySupplyChain \
  --rpc-url "$L2_RPC_URL" \
  --broadcast \
  -vvvv
```

Clear the private key:

```bash
unset PRIVATE_KEY
```

## Security model

### Application controls

- OpenZeppelin `AccessControl`;
- explicit role separation;
- constrained state transitions;
- custom errors;
- event-based audit trails;
- time-limited provider grants;
- revocable access;
- emergency-access logging;
- evidence hashes instead of confidential documents.

### Infrastructure controls

The applications run on the CodesenSys OP Stack infrastructure repository, which provides:

- separated operational accounts;
- authenticated Engine API communication;
- locally bound RPC services;
- Ethereum data publication;
- state proposal and dispute-game infrastructure;
- ignored runtime secrets and databases.

Infrastructure source and evidence:

https://github.com/CodesenSys/codesensys-op-stack-rollup

## Enterprise integration model

```text
Enterprise frontend or API
            │
            ▼
Authentication and policy layer
            │
            ▼
CodesenSys enterprise contracts
            │
            ▼
CodesenSys OP Stack L2
            │
            ▼
Ethereum settlement and data availability
```

Production systems would normally add:

- identity verification;
- key management;
- regulated off-chain storage;
- API gateways;
- indexers;
- notifications;
- analytics;
- multisignature governance;
- monitoring and incident response.

## Repository ecosystem

```text
codesensys-op-stack-rollup
        │
        ├── L1 contract deployment
        ├── L2 execution and sequencing
        ├── batch publication
        └── state proposals
                 │
                 ▼
codesensys-enterprise-op-stack
        │
        ├── HealthRecordAccessControl
        └── SupplyChainProvenance
```

## Evidence

| Evidence | Location |
|---|---|
| Network deployment | Infrastructure repository |
| Batch publication | Infrastructure `docs/evidence/batcher-proof.md` |
| Dispute-game creation | Infrastructure `docs/evidence/proposer-proof.md` |
| Enterprise deployments | `deployments/enterprise-l2.json` |
| Enterprise workflows | `docs/evidence/enterprise-l2-proof.md` |

## License

MIT
