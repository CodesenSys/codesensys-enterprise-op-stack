// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/// @title SupplyChainProvenance
/// @notice Records custody-transfer events for a physical/digital asset moving through
///         a permissioned consortium chain. Designed for an enterprise demo — role-gated
///         writes, immutable event trail, no on-chain storage of sensitive commercial data
///         (attach a hash/pointer to off-chain documents instead of raw payloads).
/// @dev Deploy on an OP Stack chain where the sequencer/allowlist restricts tx submission
///      to known consortium members; roles here are the application-layer access control
///      on top of that network-layer permissioning.
contract SupplyChainProvenance is AccessControl {
    bytes32 public constant MANUFACTURER_ROLE = keccak256("MANUFACTURER_ROLE");
    bytes32 public constant LOGISTICS_ROLE = keccak256("LOGISTICS_ROLE");
    bytes32 public constant RETAILER_ROLE = keccak256("RETAILER_ROLE");
    bytes32 public constant AUDITOR_ROLE = keccak256("AUDITOR_ROLE");

    enum Stage {
        Manufactured,
        InTransit,
        CustomsCleared,
        Received,
        Recalled
    }

    struct Checkpoint {
        Stage stage;
        address recordedBy;
        uint64 timestamp;
        bytes32 evidenceHash; // hash of an off-chain document (bill of lading, QC cert, etc.)
        string location; // free-text or geohash, kept short — this is a demo, not a DB
    }

    /// @dev assetId => ordered checkpoint history
    mapping(bytes32 => Checkpoint[]) private _history;
    /// @dev assetId => current stage, for O(1) status checks
    mapping(bytes32 => Stage) public currentStage;
    /// @dev assetId => whether it exists (registered)
    mapping(bytes32 => bool) public isRegistered;

    event AssetRegistered(bytes32 indexed assetId, address indexed manufacturer, bytes32 evidenceHash);
    event CheckpointRecorded(bytes32 indexed assetId, Stage stage, address indexed recordedBy, bytes32 evidenceHash);
    event AssetRecalled(bytes32 indexed assetId, address indexed recordedBy, bytes32 evidenceHash);

    error AssetAlreadyRegistered(bytes32 assetId);
    error AssetNotRegistered(bytes32 assetId);
    error InvalidStageTransition(Stage from, Stage to);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function registerAsset(bytes32 assetId, bytes32 evidenceHash, string calldata location)
        external
        onlyRole(MANUFACTURER_ROLE)
    {
        if (isRegistered[assetId]) revert AssetAlreadyRegistered(assetId);

        isRegistered[assetId] = true;
        currentStage[assetId] = Stage.Manufactured;
        _history[assetId].push(
            Checkpoint({
                stage: Stage.Manufactured,
                recordedBy: msg.sender,
                timestamp: uint64(block.timestamp),
                evidenceHash: evidenceHash,
                location: location
            })
        );

        emit AssetRegistered(assetId, msg.sender, evidenceHash);
    }

    function recordCheckpoint(bytes32 assetId, Stage newStage, bytes32 evidenceHash, string calldata location)
        external
    {
        if (!isRegistered[assetId]) revert AssetNotRegistered(assetId);
        _requireRoleForStage(assetId, newStage);
        _requireValidTransition(currentStage[assetId], newStage);

        currentStage[assetId] = newStage;
        _history[assetId].push(
            Checkpoint({
                stage: newStage,
                recordedBy: msg.sender,
                timestamp: uint64(block.timestamp),
                evidenceHash: evidenceHash,
                location: location
            })
        );

        emit CheckpointRecorded(assetId, newStage, msg.sender, evidenceHash);
    }

    function recallAsset(bytes32 assetId, bytes32 evidenceHash) external onlyRole(AUDITOR_ROLE) {
        if (!isRegistered[assetId]) revert AssetNotRegistered(assetId);

        currentStage[assetId] = Stage.Recalled;
        _history[assetId].push(
            Checkpoint({
                stage: Stage.Recalled,
                recordedBy: msg.sender,
                timestamp: uint64(block.timestamp),
                evidenceHash: evidenceHash,
                location: ""
            })
        );

        emit AssetRecalled(assetId, msg.sender, evidenceHash);
    }

    function getHistory(bytes32 assetId) external view returns (Checkpoint[] memory) {
        return _history[assetId];
    }

    function _requireRoleForStage(bytes32 assetId, Stage stage) internal view {
        if (stage == Stage.InTransit) _checkRole(LOGISTICS_ROLE);
        else if (stage == Stage.CustomsCleared) _checkRole(LOGISTICS_ROLE);
        else if (stage == Stage.Received) _checkRole(RETAILER_ROLE);
        else revert InvalidStageTransition(currentStage[assetId], stage);
    }

    function _requireValidTransition(Stage from, Stage to) internal pure {
        bool valid = (from == Stage.Manufactured && to == Stage.InTransit)
            || (from == Stage.InTransit && to == Stage.CustomsCleared)
            || (from == Stage.CustomsCleared && to == Stage.Received)
            || (from == Stage.InTransit && to == Stage.Received);
        if (!valid) revert InvalidStageTransition(from, to);
    }
}
