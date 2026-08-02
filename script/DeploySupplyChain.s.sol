// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {SupplyChainProvenance} from "../src/SupplyChainProvenance.sol";

contract DeploySupplyChain is Script {
    function run() external returns (SupplyChainProvenance deployed) {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address admin = vm.envAddress("ADMIN_ADDRESS");

        vm.startBroadcast(privateKey);
        deployed = new SupplyChainProvenance(admin);
        vm.stopBroadcast();
    }
}
