// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {HealthRecordAccessControl} from "../src/HealthRecordAccessControl.sol";

contract DeployHealthAccess is Script {
    function run() external returns (HealthRecordAccessControl deployed) {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address admin = vm.envAddress("ADMIN_ADDRESS");

        vm.startBroadcast(privateKey);
        deployed = new HealthRecordAccessControl(admin);
        vm.stopBroadcast();
    }
}
