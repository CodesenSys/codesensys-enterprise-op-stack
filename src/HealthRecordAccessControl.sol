// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/// @title HealthRecordAccessControl
/// @notice Patient-controlled access grants for encrypted off-chain health records.
///         This contract NEVER stores PHI (protected health information) on-chain — only
///         a pointer (e.g. IPFS CID or storage URI hash) and a symmetric-key wrapper hash
///         for each record, plus time-boxed access grants to providers. Decryption keys
///         are exchanged off-chain (e.g. via the provider's public key) once a grant is
///         active; this contract is the audit trail and access gate, not the data store.
/// @dev Intended for a permissioned OP Stack chain where only vetted providers/patients
///      hold accounts — network-layer permissioning is the first line of defense, this
///      contract is the second (per-record, per-provider, time-boxed).
contract HealthRecordAccessControl is AccessControl {
    bytes32 public constant PROVIDER_ROLE = keccak256("PROVIDER_ROLE");
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");

    struct RecordPointer {
        address patient;
        uint64 createdAt;
        bytes32 storageRef; // hash/CID of the encrypted record blob, stored off-chain
    }

    struct Grant {
        bool active;
        uint64 expiresAt;
        bytes32 reasonCode; // e.g. keccak256("REFERRAL") — kept as a code, not free text
    }

    /// @dev recordId => pointer metadata
    mapping(bytes32 => RecordPointer) public records;
    /// @dev recordId => provider => grant
    mapping(bytes32 => mapping(address => Grant)) public grants;
    /// @dev break-glass emergency accesses, logged separately for compliance review
    mapping(bytes32 => mapping(address => uint64))
        public emergencyAccessLoggedAt;

    event RecordRegistered(
        bytes32 indexed recordId,
        address indexed patient,
        bytes32 storageRef
    );
    event AccessGranted(
        bytes32 indexed recordId,
        address indexed patient,
        address indexed provider,
        uint64 expiresAt,
        bytes32 reasonCode
    );
    event AccessRevoked(
        bytes32 indexed recordId,
        address indexed patient,
        address indexed provider
    );
    event EmergencyAccessUsed(
        bytes32 indexed recordId,
        address indexed provider,
        address loggedBy
    );

    error NotRecordOwner(bytes32 recordId, address caller);
    error RecordAlreadyExists(bytes32 recordId);
    error GrantNotActive(bytes32 recordId, address provider);
    error GrantExpired(bytes32 recordId, address provider, uint64 expiresAt);

    constructor(address admin) {
        _setRoleAdmin(PROVIDER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(COMPLIANCE_ROLE, DEFAULT_ADMIN_ROLE);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(COMPLIANCE_ROLE, admin);
    }

    modifier onlyPatient(bytes32 recordId) {
        _onlyPatient(recordId);
        _;
    }

    function _onlyPatient(bytes32 recordId) internal view {
        if (records[recordId].patient != msg.sender)
            revert NotRecordOwner(recordId, msg.sender);
    }

    /// @notice Patient registers a pointer to their own encrypted record.
    function registerRecord(bytes32 recordId, bytes32 storageRef) external {
        if (records[recordId].patient != address(0))
            revert RecordAlreadyExists(recordId);

        records[recordId] = RecordPointer({
            patient: msg.sender,
            storageRef: storageRef,
            createdAt: uint64(block.timestamp)
        });

        emit RecordRegistered(recordId, msg.sender, storageRef);
    }

    /// @notice Patient grants a vetted provider time-boxed access to a specific record.
    function grantAccess(
        bytes32 recordId,
        address provider,
        uint64 durationSeconds,
        bytes32 reasonCode
    ) external onlyPatient(recordId) {
        require(hasRole(PROVIDER_ROLE, provider), "provider not credentialed");

        uint64 expiresAt = uint64(block.timestamp) + durationSeconds;
        grants[recordId][provider] = Grant({
            active: true,
            expiresAt: expiresAt,
            reasonCode: reasonCode
        });

        emit AccessGranted(
            recordId,
            msg.sender,
            provider,
            expiresAt,
            reasonCode
        );
    }

    /// @notice Patient revokes a provider's access before it naturally expires.
    function revokeAccess(
        bytes32 recordId,
        address provider
    ) external onlyPatient(recordId) {
        grants[recordId][provider].active = false;
        emit AccessRevoked(recordId, msg.sender, provider);
    }

    /// @notice Providers call this to prove (on-chain) they have a live grant before an
    ///         off-chain service hands them the decryption key. Reverts if not entitled.
    function assertAccess(
        bytes32 recordId,
        address provider
    ) external view returns (bytes32 storageRef) {
        Grant memory g = grants[recordId][provider];
        if (!g.active) revert GrantNotActive(recordId, provider);
        if (block.timestamp > g.expiresAt)
            revert GrantExpired(recordId, provider, g.expiresAt);
        return records[recordId].storageRef;
    }

    /// @notice Break-glass path for emergencies — compliance role must co-sign by logging
    ///         the access after the fact for audit. Real deployments would pair this with
    ///         an off-chain alerting workflow, not just an on-chain log.
    function logEmergencyAccess(
        bytes32 recordId,
        address provider
    ) external onlyRole(COMPLIANCE_ROLE) {
        emergencyAccessLoggedAt[recordId][provider] = uint64(block.timestamp);
        emit EmergencyAccessUsed(recordId, provider, msg.sender);
    }
}
