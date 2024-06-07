// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {Test, console} from "forge-std/Test.sol";
import {L3ExchangeUpgradeable} from "../src/L3ExchangeUpgradeable.sol";
import {ERC721Test} from "../src/ERC721Test.sol";
import {WETH9} from "../src/WETH.sol";

import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";

import {IBeacon} from "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import {OrderStructs} from "../src/libraries/OrderStructs.sol";

import {QuoteType} from "../src/enums/QuoteType.sol";

import {CollectionType} from "../src/enums/CollectionType.sol";
import {LibRoles} from "../src/constants/RoleConstants.sol";

contract L3ExchangeUpgradeableTest is Test, IERC721Receiver {
    L3ExchangeUpgradeable l3Exchange;
    ERC721Test erc721Sample;
    WETH9 weth;
    address _addr1 = vm.addr(0x12);
    address _addr2 = makeAddr("ADDR2");

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function setup() public {
        weth = new WETH9();

        address proxyERC721 = Upgrades.deployUUPSProxy(
            "ERC721Test.sol",
            abi.encodeCall(
                ERC721Test.initialize,
                (address(this), "ERC721Test", "COL")
            )
        );

        erc721Sample = ERC721Test((proxyERC721));

        erc721Sample.mint(_addr1);

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
                    _addr2,
                    _addr2
                )
            )
        );

        l3Exchange = L3ExchangeUpgradeable(payable(proxy));

        l3Exchange.setProtocolFee(address(this), 1000);

        l3Exchange.grantRole(LibRoles.CURRENCY_ROLE, address(weth));
        vm.warp(1717734579);
    }

    function test_Setup() public {
        setup();
        assertEq(erc721Sample.balanceOf(_addr1), 1);
        (address _protocolFeeRecipient, uint256 _protocolFee) = l3Exchange
            .viewProtocolFeeInfo();
        assertEq(_protocolFeeRecipient, _addr2);
        assertEq(_protocolFee, 1000);

        assertEq(
            l3Exchange.hasRole(LibRoles.CURRENCY_ROLE, address(weth)),
            true
        );
    }

    function testExecuteOrder() public {
        setup();
        erc721Sample.setApprovalForAll(address(l3Exchange), true);

        OrderStructs.Maker memory maker = OrderStructs.Maker({
            quoteType: QuoteType.Ask,
            orderNonce: 0,
            collectionType: CollectionType.ERC721,
            collection: address(erc721Sample),
            tokenId: 1,
            currency: address(weth),
            price: 10,
            signer: _addr1,
            startTime: 1717734574,
            endTime: 1817495738,
            assets: new address[](0),
            values: new uint256[](0),
            makerSignature: new bytes(0)
        });
        bytes32 _MAKER_TYPEHASH = 0x5f3e890c36d263fd3e4b97d606b6456effba4409d05897000409303ba8dcf2f4;

        bytes32 makerHash = keccak256(
            bytes.concat(
                abi.encode(
                    _MAKER_TYPEHASH,
                    maker.quoteType,
                    maker.orderNonce,
                    maker.collectionType,
                    maker.collection,
                    maker.tokenId,
                    maker.currency,
                    maker.price,
                    maker.signer,
                    maker.startTime,
                    maker.endTime,
                    keccak256(abi.encodePacked(maker.assets)),
                    keccak256(abi.encodePacked(maker.values))
                )
            )
        );

        (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        ) = l3Exchange.eip712Domain();

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(0x12, makerHash);

        maker.makerSignature = abi.encodePacked(v, r, s);

        // console.log("makerHash", makerHash);

        l3Exchange.executeOrder(
            maker,
            OrderStructs.Taker({
                recipient: _addr1,
                takerSignature: new bytes(0)
            })
        );

        assertEq(weth.balanceOf(address(this)), 1);
    }
}
