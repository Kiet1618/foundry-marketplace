// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {Test, console} from "forge-std/Test.sol";
import {L3ExchangeUpgradeable} from "../src/L3ExchangeUpgradeable.sol";
import {ERC721Sample} from "../src/ERC721Sample.sol";
import {WETH9} from "../src/WETH.sol";

import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";

import {IBeacon} from "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import {OrderStructs} from "../src/libraries/OrderStructs.sol";

import {QuoteType} from "../src/enums/QuoteType.sol";

import {CollectionType} from "../src/enums/CollectionType.sol";

contract L3ExchangeUpgradeableTest is Test, IERC721Receiver {
    L3ExchangeUpgradeable l3Exchange;
    ERC721Sample erc721Sample;
    WETH9 weth;
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

    function testUUPS() public {
        weth = new WETH9();

        address proxyERC721 = Upgrades.deployUUPSProxy(
            "ERC721Sample.sol",
            abi.encodeCall(
                ERC721Sample.initialize,
                (address(this), "ERC721Sample", "COL")
            )
        );

        erc721Sample = ERC721Sample(payable(proxyERC721));

        address proxy = Upgrades.deployUUPSProxy(
            "L3ExchangeUpgradeable.sol",
            abi.encodeCall(
                L3ExchangeUpgradeable.initialize,
                (
                    "L3ExchangeUpgradeable",
                    "1.0.0",
                    address(this),
                    address(this),
                    address(erc721Sample),
                    address(erc721Sample),
                    address(erc721Sample)
                )
            )
        );

        l3Exchange = L3ExchangeUpgradeable(payable(proxy));
    }

    // function testExecuteOrder() public {
    //     erc721Sample.mint(address(this));

    //     erc721Sample.setApprovalForAll(address(l3Exchange), true);

    //     OrderStructs.Maker memory maker = OrderStructs.Maker({
    //         quoteType: QuoteType.Ask,
    //         orderNonce: 0,
    //         collectionType: CollectionType.ERC721,
    //         collection: address(erc721Sample),
    //         tokenId: 1,
    //         currency: address(weth),
    //         price: 10,
    //         signer: address(this),
    //         startTime: 1717495754,
    //         endTime: 1817495738,
    //         assets: new address[](0),
    //         values: new uint256[](0),
    //         makerSignature: new bytes(0)
    //     });
    //     bytes32 _MAKER_TYPEHASH = 0x5f3e890c36d263fd3e4b97d606b6456effba4409d05897000409303ba8dcf2f4;

    //     bytes32 signature = keccak256(
    //         bytes.concat(
    //             abi.encode(
    //                 _MAKER_TYPEHASH,
    //                 maker.quoteType,
    //                 maker.orderNonce,
    //                 maker.collectionType,
    //                 maker.collection,
    //                 maker.tokenId,
    //                 maker.currency,
    //                 maker.price,
    //                 maker.signer,
    //                 maker.startTime,
    //                 maker.endTime,
    //                 keccak256(abi.encodePacked(maker.assets)),
    //                 keccak256(abi.encodePacked(maker.values))
    //             )
    //         )
    //     );

    //     maker.makerSignature = abi.encodePacked(signature);

    //     l3Exchange.executeOrder(
    //         maker,
    //         OrderStructs.Taker({
    //             recipient: _addr1,
    //             takerSignature: new bytes(0)
    //         })
    //     );

    //     assertEq(weth.balanceOf(address(this)), 1);
    // }
}
