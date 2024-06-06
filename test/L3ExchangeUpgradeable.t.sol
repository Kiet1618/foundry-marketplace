// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {Test, console} from "forge-std/Test.sol";
import {L3ExchangeUpgradeable} from "../src/L3ExchangeUpgradeable.sol";
import {ERC721Sample} from "../src/ERC721Sample.sol";
import {WETH9} from "../src/WETH.sol";

contract L3ExchangeUpgradeableTest is Test, IERC721Receiver {
    L3ExchangeUpgradeable l3Exchange;
    L3ExchangeUpgradeable l3ExchangeProxy;
    ERC721Sample erc721Sample;
    WETH9 weth;

    address _admin = makeAddr("ADMIN");
    address _operator = makeAddr("OPERATOR");
    address _addr1 = makeAddr("ADDR1");
    address _addr2 = makeAddr("ADDR2");

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function setUp() public {
        l3Exchange = new L3ExchangeUpgradeable();
        erc721Sample = new ERC721Sample();
        weth = new WETH9();

        l3ExchangeProxy = L3ExchangeUpgradeable.initialize(
            "L3Exchange",
            "1",
            _admin,
            _operator,
            address(erc721Sample),
            address(weth),
            address(weth)
        );
    }

    function test_Initialize() public view {
        assertEq(
            l3Exchange.hasRole(l3Exchange.DEFAULT_ADMIN_ROLE(), address(this)),
            true
        );
    }
}
