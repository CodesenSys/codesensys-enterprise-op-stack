// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {SupplyChainProvenance} from "../src/SupplyChainProvenance.sol";

contract SupplyChainProvenanceTest is Test {
    SupplyChainProvenance internal provenance;

    address internal admin = makeAddr("admin");
    address internal manufacturer = makeAddr("manufacturer");
    address internal logistics = makeAddr("logistics");
    address internal retailer = makeAddr("retailer");
    address internal auditor = makeAddr("auditor");
    address internal outsider = makeAddr("outsider");

    bytes32 internal constant ASSET_ID = keccak256("ASSET-001");
    bytes32 internal constant MFG_EVIDENCE = keccak256("synthetic-manufacturing-certificate");
    bytes32 internal constant TRANSIT_EVIDENCE = keccak256("synthetic-bill-of-lading");
    bytes32 internal constant CUSTOMS_EVIDENCE = keccak256("synthetic-customs-clearance");
    bytes32 internal constant RECEIPT_EVIDENCE = keccak256("synthetic-receipt");
    bytes32 internal constant RECALL_EVIDENCE = keccak256("synthetic-recall-notice");

    event AssetRegistered(bytes32 indexed assetId, address indexed manufacturer, bytes32 evidenceHash);
    event CheckpointRecorded(
        bytes32 indexed assetId, SupplyChainProvenance.Stage stage, address indexed recordedBy, bytes32 evidenceHash
    );
    event AssetRecalled(bytes32 indexed assetId, address indexed recordedBy, bytes32 evidenceHash);

    function setUp() public {
        provenance = new SupplyChainProvenance(admin);

        vm.startPrank(admin);
        provenance.grantRole(provenance.MANUFACTURER_ROLE(), manufacturer);
        provenance.grantRole(provenance.LOGISTICS_ROLE(), logistics);
        provenance.grantRole(provenance.RETAILER_ROLE(), retailer);
        provenance.grantRole(provenance.AUDITOR_ROLE(), auditor);
        vm.stopPrank();
    }

    function test_RegisterAsset_SucceedsForManufacturerAndEmitsEvent() public {
        vm.expectEmit(true, true, false, true, address(provenance));
        emit AssetRegistered(ASSET_ID, manufacturer, MFG_EVIDENCE);

        vm.prank(manufacturer);
        provenance.registerAsset(ASSET_ID, MFG_EVIDENCE, "Lahore Factory");

        assertTrue(provenance.isRegistered(ASSET_ID));
        assertEq(uint256(provenance.currentStage(ASSET_ID)), uint256(SupplyChainProvenance.Stage.Manufactured));
    }

    function test_RegisterAsset_RevertsForUnauthorizedCaller() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, outsider, provenance.MANUFACTURER_ROLE()
            )
        );
        vm.prank(outsider);
        provenance.registerAsset(ASSET_ID, MFG_EVIDENCE, "Unknown");
    }

    function test_RegisterAsset_RevertsOnDuplicate() public {
        _registerAsset();

        vm.expectRevert(abi.encodeWithSelector(SupplyChainProvenance.AssetAlreadyRegistered.selector, ASSET_ID));
        vm.prank(manufacturer);
        provenance.registerAsset(ASSET_ID, MFG_EVIDENCE, "Duplicate");
    }

    function test_RecordCheckpoint_RevertsForUnregisteredAsset() public {
        vm.expectRevert(abi.encodeWithSelector(SupplyChainProvenance.AssetNotRegistered.selector, ASSET_ID));
        vm.prank(logistics);
        provenance.recordCheckpoint(ASSET_ID, SupplyChainProvenance.Stage.InTransit, TRANSIT_EVIDENCE, "Lahore Hub");
    }

    function test_RecordCheckpoint_RequiresLogisticsRoleForInTransit() public {
        _registerAsset();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, outsider, provenance.LOGISTICS_ROLE()
            )
        );
        vm.prank(outsider);
        provenance.recordCheckpoint(ASSET_ID, SupplyChainProvenance.Stage.InTransit, TRANSIT_EVIDENCE, "Lahore Hub");
    }

    function test_RecordCheckpoint_RequiresRetailerRoleForReceived() public {
        _registerAsset();
        _recordInTransit();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, outsider, provenance.RETAILER_ROLE()
            )
        );
        vm.prank(outsider);
        provenance.recordCheckpoint(ASSET_ID, SupplyChainProvenance.Stage.Received, RECEIPT_EVIDENCE, "Retail Store");
    }

    function test_RecordCheckpoint_EmitsEventAndAdvancesStage() public {
        _registerAsset();

        vm.expectEmit(true, true, false, true, address(provenance));
        emit CheckpointRecorded(ASSET_ID, SupplyChainProvenance.Stage.InTransit, logistics, TRANSIT_EVIDENCE);

        vm.prank(logistics);
        provenance.recordCheckpoint(ASSET_ID, SupplyChainProvenance.Stage.InTransit, TRANSIT_EVIDENCE, "Lahore Hub");

        assertEq(uint256(provenance.currentStage(ASSET_ID)), uint256(SupplyChainProvenance.Stage.InTransit));
    }

    function test_RecordCheckpoint_RevertsOnIllegalJump() public {
        _registerAsset();

        vm.expectRevert(
            abi.encodeWithSelector(
                SupplyChainProvenance.InvalidStageTransition.selector,
                SupplyChainProvenance.Stage.Manufactured,
                SupplyChainProvenance.Stage.Received
            )
        );
        vm.prank(retailer);
        provenance.recordCheckpoint(ASSET_ID, SupplyChainProvenance.Stage.Received, RECEIPT_EVIDENCE, "Retail Store");
    }

    function test_RecordCheckpoint_RevertsForUnsupportedTargetStage() public {
        _registerAsset();

        vm.expectRevert(
            abi.encodeWithSelector(
                SupplyChainProvenance.InvalidStageTransition.selector,
                SupplyChainProvenance.Stage.Manufactured,
                SupplyChainProvenance.Stage.Recalled
            )
        );
        vm.prank(logistics);
        provenance.recordCheckpoint(ASSET_ID, SupplyChainProvenance.Stage.Recalled, RECALL_EVIDENCE, "");
    }

    function test_RecallAsset_OnlyAuditorCanRecall() public {
        _registerAsset();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, outsider, provenance.AUDITOR_ROLE()
            )
        );
        vm.prank(outsider);
        provenance.recallAsset(ASSET_ID, RECALL_EVIDENCE);
    }

    function test_RecallAsset_RevertsForUnregisteredAsset() public {
        vm.expectRevert(abi.encodeWithSelector(SupplyChainProvenance.AssetNotRegistered.selector, ASSET_ID));
        vm.prank(auditor);
        provenance.recallAsset(ASSET_ID, RECALL_EVIDENCE);
    }

    function test_RecallAsset_SetsStageAndEmitsEvent() public {
        _registerAsset();

        vm.expectEmit(true, true, false, true, address(provenance));
        emit AssetRecalled(ASSET_ID, auditor, RECALL_EVIDENCE);

        vm.prank(auditor);
        provenance.recallAsset(ASSET_ID, RECALL_EVIDENCE);

        assertEq(uint256(provenance.currentStage(ASSET_ID)), uint256(SupplyChainProvenance.Stage.Recalled));
    }

    function test_GetHistory_ReturnsCheckpointsInOrder() public {
        vm.warp(1_000);
        _registerAsset();
        vm.warp(1_100);
        _recordInTransit();
        vm.warp(1_200);
        _recordCustomsCleared();
        vm.warp(1_300);
        _recordReceived();

        SupplyChainProvenance.Checkpoint[] memory history = provenance.getHistory(ASSET_ID);
        assertEq(history.length, 4);

        assertEq(uint256(history[0].stage), uint256(SupplyChainProvenance.Stage.Manufactured));
        assertEq(history[0].recordedBy, manufacturer);
        assertEq(history[0].timestamp, 1_000);
        assertEq(history[0].evidenceHash, MFG_EVIDENCE);
        assertEq(history[0].location, "Lahore Factory");

        assertEq(uint256(history[1].stage), uint256(SupplyChainProvenance.Stage.InTransit));
        assertEq(history[1].recordedBy, logistics);
        assertEq(history[1].timestamp, 1_100);

        assertEq(uint256(history[2].stage), uint256(SupplyChainProvenance.Stage.CustomsCleared));
        assertEq(history[2].recordedBy, logistics);
        assertEq(history[2].timestamp, 1_200);

        assertEq(uint256(history[3].stage), uint256(SupplyChainProvenance.Stage.Received));
        assertEq(history[3].recordedBy, retailer);
        assertEq(history[3].timestamp, 1_300);
    }

    function test_InTransitCanTransitionDirectlyToReceived() public {
        _registerAsset();
        _recordInTransit();
        _recordReceived();

        assertEq(uint256(provenance.currentStage(ASSET_ID)), uint256(SupplyChainProvenance.Stage.Received));
    }

    function _registerAsset() internal {
        vm.prank(manufacturer);
        provenance.registerAsset(ASSET_ID, MFG_EVIDENCE, "Lahore Factory");
    }

    function _recordInTransit() internal {
        vm.prank(logistics);
        provenance.recordCheckpoint(ASSET_ID, SupplyChainProvenance.Stage.InTransit, TRANSIT_EVIDENCE, "Lahore Hub");
    }

    function _recordCustomsCleared() internal {
        vm.prank(logistics);
        provenance.recordCheckpoint(
            ASSET_ID, SupplyChainProvenance.Stage.CustomsCleared, CUSTOMS_EVIDENCE, "Karachi Customs"
        );
    }

    function _recordReceived() internal {
        vm.prank(retailer);
        provenance.recordCheckpoint(ASSET_ID, SupplyChainProvenance.Stage.Received, RECEIPT_EVIDENCE, "Retail Store");
    }
}
