// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {HealthRecordAccessControl} from "../src/HealthRecordAccessControl.sol";

contract HealthRecordAccessControlTest is Test {
    HealthRecordAccessControl internal accessControl;

    address internal admin = makeAddr("admin");
    address internal patient = makeAddr("patient");
    address internal provider = makeAddr("provider");
    address internal uncredentialedProvider =
        makeAddr("uncredentialed-provider");
    address internal outsider = makeAddr("outsider");

    bytes32 internal constant RECORD_ID = keccak256("SYNTHETIC-RECORD-001");
    bytes32 internal constant STORAGE_REF =
        keccak256("encrypted-offchain-record-pointer");
    bytes32 internal constant REASON_CODE = keccak256("REFERRAL");

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

    function setUp() public {
        vm.warp(1_000_000);
        accessControl = new HealthRecordAccessControl(admin);

        vm.prank(admin);
        accessControl.grantRole(accessControl.PROVIDER_ROLE(), provider);
    }

    function test_RegisterRecord_StoresSyntheticPointerAndEmitsEvent() public {
        vm.expectEmit(true, true, false, true, address(accessControl));
        emit RecordRegistered(RECORD_ID, patient, STORAGE_REF);

        vm.prank(patient);
        accessControl.registerRecord(RECORD_ID, STORAGE_REF);

        (
            address storedPatient,
            uint64 createdAt,
            bytes32 storedRef
        ) = accessControl.records(RECORD_ID);
        assertEq(storedPatient, patient);
        assertEq(storedRef, STORAGE_REF);
        assertEq(createdAt, block.timestamp);
    }

    function test_RegisterRecord_RevertsOnDuplicate() public {
        _registerRecord();

        vm.expectRevert(
            abi.encodeWithSelector(
                HealthRecordAccessControl.RecordAlreadyExists.selector,
                RECORD_ID
            )
        );
        vm.prank(patient);
        accessControl.registerRecord(RECORD_ID, STORAGE_REF);
    }

    function test_GrantAccess_RevertsWhenCallerIsNotPatient() public {
        _registerRecord();

        vm.expectRevert(
            abi.encodeWithSelector(
                HealthRecordAccessControl.NotRecordOwner.selector,
                RECORD_ID,
                outsider
            )
        );
        vm.prank(outsider);
        accessControl.grantAccess(RECORD_ID, provider, 1 hours, REASON_CODE);
    }

    function test_GrantAccess_RevertsForUncredentialedProvider() public {
        _registerRecord();

        vm.expectRevert(bytes("provider not credentialed"));
        vm.prank(patient);
        accessControl.grantAccess(
            RECORD_ID,
            uncredentialedProvider,
            1 hours,
            REASON_CODE
        );
    }

    function test_GrantAccess_StoresGrantAndEmitsEvent() public {
        _registerRecord();
        uint64 expectedExpiry = uint64(block.timestamp + 1 hours);

        vm.expectEmit(true, true, true, true, address(accessControl));
        emit AccessGranted(
            RECORD_ID,
            patient,
            provider,
            expectedExpiry,
            REASON_CODE
        );

        vm.prank(patient);
        accessControl.grantAccess(RECORD_ID, provider, 1 hours, REASON_CODE);

        (bool active, uint64 expiresAt, bytes32 reasonCode) = accessControl
            .grants(RECORD_ID, provider);
        assertTrue(active);
        assertEq(expiresAt, expectedExpiry);
        assertEq(reasonCode, REASON_CODE);
    }

    function test_AssertAccess_ReturnsStorageRefWithinGrantWindow() public {
        _registerAndGrant(1 hours);

        vm.warp(block.timestamp + 30 minutes);
        bytes32 returnedRef = accessControl.assertAccess(RECORD_ID, provider);
        assertEq(returnedRef, STORAGE_REF);
    }

    function test_AssertAccess_IsValidAtExactExpiry() public {
        _registerAndGrant(1 hours);
        (, uint64 expiresAt, ) = accessControl.grants(RECORD_ID, provider);

        vm.warp(expiresAt);
        assertEq(accessControl.assertAccess(RECORD_ID, provider), STORAGE_REF);
    }

    function test_AssertAccess_RevertsAfterExpiry() public {
        _registerAndGrant(1 hours);
        (, uint64 expiresAt, ) = accessControl.grants(RECORD_ID, provider);
        vm.warp(uint256(expiresAt) + 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                HealthRecordAccessControl.GrantExpired.selector,
                RECORD_ID,
                provider,
                expiresAt
            )
        );
        accessControl.assertAccess(RECORD_ID, provider);
    }

    function test_AssertAccess_RevertsWithoutActiveGrant() public {
        _registerRecord();

        vm.expectRevert(
            abi.encodeWithSelector(
                HealthRecordAccessControl.GrantNotActive.selector,
                RECORD_ID,
                provider
            )
        );
        accessControl.assertAccess(RECORD_ID, provider);
    }

    function test_RevokeAccess_ImmediatelyBlocksAccessAndEmitsEvent() public {
        _registerAndGrant(1 hours);

        vm.expectEmit(true, true, true, false, address(accessControl));
        emit AccessRevoked(RECORD_ID, patient, provider);
        vm.prank(patient);
        accessControl.revokeAccess(RECORD_ID, provider);

        vm.expectRevert(
            abi.encodeWithSelector(
                HealthRecordAccessControl.GrantNotActive.selector,
                RECORD_ID,
                provider
            )
        );
        accessControl.assertAccess(RECORD_ID, provider);
    }

    function test_RevokeAccess_RevertsWhenCallerIsNotPatient() public {
        _registerAndGrant(1 hours);

        vm.expectRevert(
            abi.encodeWithSelector(
                HealthRecordAccessControl.NotRecordOwner.selector,
                RECORD_ID,
                outsider
            )
        );
        vm.prank(outsider);
        accessControl.revokeAccess(RECORD_ID, provider);
    }

    function test_LogEmergencyAccess_AdminComplianceRoleSucceedsAndEmitsEvent()
        public
    {
        _registerRecord();

        vm.expectEmit(true, true, false, true, address(accessControl));
        emit EmergencyAccessUsed(RECORD_ID, provider, admin);

        vm.prank(admin);
        accessControl.logEmergencyAccess(RECORD_ID, provider);

        assertEq(
            accessControl.emergencyAccessLoggedAt(RECORD_ID, provider),
            block.timestamp
        );
    }

    function test_LogEmergencyAccess_RevertsWithoutComplianceRole() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                outsider,
                accessControl.COMPLIANCE_ROLE()
            )
        );
        vm.prank(outsider);
        accessControl.logEmergencyAccess(RECORD_ID, provider);
    }

    function test_NoPHIStoredOnlySyntheticHashesAndCodes() public {
        _registerAndGrant(1 hours);

        (, , bytes32 storedRef) = accessControl.records(RECORD_ID);
        (, , bytes32 storedReasonCode) = accessControl.grants(
            RECORD_ID,
            provider
        );

        assertEq(storedRef, STORAGE_REF);
        assertEq(storedReasonCode, REASON_CODE);
    }

    function _registerRecord() internal {
        vm.prank(patient);
        accessControl.registerRecord(RECORD_ID, STORAGE_REF);
    }

    function _registerAndGrant(uint64 duration) internal {
        _registerRecord();
        vm.prank(patient);
        accessControl.grantAccess(RECORD_ID, provider, duration, REASON_CODE);
    }
}
