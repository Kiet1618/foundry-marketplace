// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";

contract L3Exchange is Script {
    function setUp() public {}

    function run() public {
        vm.broadcast();

        // address l3Exchange = Upgrades.deployProxy(
        //     address(l3Exchange),
        //     address(
        //         Options({
        //             value: 0,
        //             salt: 0,
        //             nonce: 0,
        //             kind: 0,
        //             admin: address(0),
        //             beacon: address(0),
        //             implementation: address(0),
        //             initializer: abi.encodeWithSignature("initialize()")
        //         })
        //     )
        // );
    }
}
