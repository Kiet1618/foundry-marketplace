// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {Test, console} from "forge-std/Test.sol";

contract ERC721Test is Test, IERC721Receiver {
    GameItem erc721;

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function setUp() public {
        erc721 = new GameItem();
    }

    function test_name() public view {
        assertEq(erc721.name(), "GameItem");
    }

    function test_mint() public {
        erc721.createItem("https://game.example/item-id-8u5h2m.json");
        assertEq(erc721.balanceOf(address(this)), 1);
        assertEq(
            erc721.tokenURI(1),
            "https://game.example/item-id-8u5h2m.json"
        );
    }
}
