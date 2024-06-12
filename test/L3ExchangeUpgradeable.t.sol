// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {Test} from "forge-std/Test.sol";

import {L3ExchangeUpgradeable} from "../src/L3ExchangeUpgradeable.sol";
import {ERC721Test} from "../src/ERC721Test.sol";
import {ERC1155Test} from "../src/ERC1155Test.sol";
import {WETH9} from "../src/WETH.sol";

import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";

import {IBeacon} from "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import {OrderStructs} from "../src/libraries/OrderStructs.sol";

import {QuoteType} from "../src/enums/QuoteType.sol";

import {CollectionType} from "../src/enums/CollectionType.sol";
import {LibRoles} from "../src/constants/RoleConstants.sol";

import {console} from "forge-std/console.sol";

import {SigUtils} from "./SigUtils.sol";
import {IERC6551Registry} from "../src/interfaces/IERC6551Registry.sol";

contract L3ExchangeUpgradeableTest is Test, IERC721Receiver {
    L3ExchangeUpgradeable l3Exchange;
    ERC721Test erc721Sample;
    WETH9 weth;
    uint256 pkMaker = 0x12;
    uint256 pkTaker = 0x10;
    address _addr1 = vm.addr(pkMaker);
    address _addr2 = vm.addr(pkTaker);
    address _feeRecipient = vm.addr(0x11);
    SigUtils sigUtils;
    address addrImplemention;
    address addrResgiter;
    IERC6551Registry erc661Registry;
    address _tba;
    ERC1155Test erc1155Sample;

    receive() external payable {}

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function setUp() public {
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

        addrImplemention = 0x2D25602551487C3f3354dD80D76D54383A243358;
        addrResgiter = 0x02101dfB77FDE026414827Fdc604ddAF224F0921;

        erc661Registry = IERC6551Registry(addrResgiter);

        _tba = erc661Registry.createAccount(
            addrImplemention,
            11155111,
            address(erc721Sample),
            1,
            0,
            abi.encodePacked()
        );

        erc721Sample.mint(address(this));

        erc721Sample.transferFrom(address(this), _tba, 2);

        address proxyERC1155 = Upgrades.deployUUPSProxy(
            "ERC1155Test.sol",
            abi.encodeCall(ERC1155Test.initialize, ("ERC1155Test"))
        );

        erc1155Sample = ERC1155Test((proxyERC1155));

        erc1155Sample.mint(_addr1, 1, 1, "");
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
                    address(erc1155Sample),
                    addrResgiter,
                    addrImplemention
                )
            )
        );

        l3Exchange = L3ExchangeUpgradeable(payable(proxy));

        l3Exchange.setProtocolFee(_feeRecipient, 1000);

        l3Exchange.grantRole(LibRoles.CURRENCY_ROLE, address(weth));

        vm.warp(1717734579);

        vm.prank(_addr1);
        erc721Sample.setApprovalForAll(address(l3Exchange), true);
        vm.prank(_addr1);
        erc1155Sample.setApprovalForAll(address(l3Exchange), true);

        // check erc1155 approval

        // assertEq(
        //     erc721Sample.isApprovedForAll(_addr1, address(l3Exchange)),
        //     true
        // );

        assertEq(
            erc1155Sample.isApprovedForAll(_addr1, address(l3Exchange)),
            true
        );

        // assertEq(
        //     l3Exchange.hasRole(LibRoles.COLLECTION_ROLE, address(erc721Sample)),
        //     true
        // );

        // assertEq(
        //     l3Exchange.hasRole(
        //         LibRoles.COLLECTION_ROLE,
        //         address(erc1155Sample)
        //     ),
        //     true
        // );

        sigUtils = new SigUtils(l3Exchange.DOMAIN_SEPARATOR());
        vm.prank(_addr2);
        vm.deal(_addr2, 10 ether);
    }

    function test_Setup() public view {
        assertEq(erc721Sample.balanceOf(_addr1), 1);
        assertEq(erc721Sample.ownerOf(1), _addr1);
        (address _protocolFeeRecipient, uint256 _protocolFee) = l3Exchange
            .viewProtocolFeeInfo();
        assertEq(_protocolFeeRecipient, _feeRecipient);
        assertEq(_protocolFee, 1000);

        assertEq(
            l3Exchange.hasRole(LibRoles.CURRENCY_ROLE, address(weth)),
            true
        );

        assertEq(erc721Sample.ownerOf(2), _tba);
        assertEq(erc1155Sample.balanceOf(_addr1, 1), 1);
    }

    function test_createAccountTBA() public view {
        address account = erc661Registry.account(
            addrImplemention,
            11155111,
            address(erc721Sample),
            1,
            0
        );

        assertEq(account, _tba);
    }

    function testExecuteAskNative() public {
        OrderStructs.Maker memory maker = OrderStructs.Maker({
            quoteType: QuoteType.Ask,
            orderNonce: 0,
            collectionType: CollectionType.ERC721,
            collection: address(erc721Sample),
            tokenId: 1,
            amount: 0,
            currency: 0x0000000000000000000000000000000000000000,
            price: 0.1 ether,
            signer: _addr1,
            startTime: 1717734579,
            endTime: 1717734579,
            assets: new address[](0),
            values: new uint256[](0),
            makerSignature: new bytes(0)
        });
        bytes32 digest = sigUtils.getTypeDataHash(
            sigUtils.getStructHash(maker)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pkMaker, digest);

        maker.makerSignature = sigUtils.combineSignature(v, r, s);
        OrderStructs.Taker memory taker = OrderStructs.Taker({
            recipient: _addr2,
            takerSignature: new bytes(0)
        });
        l3Exchange.executeOrder{value: 0.1 ether}(maker, taker);
    }

    function testExecuteBidNative() public {
        weth.approve(address(l3Exchange), 1 ether);
        OrderStructs.Maker memory maker = OrderStructs.Maker({
            quoteType: QuoteType.Bid,
            orderNonce: 0,
            collectionType: CollectionType.ERC721,
            collection: address(erc721Sample),
            tokenId: 1,
            amount: 0,
            currency: 0x0000000000000000000000000000000000000000,
            price: 0.1 ether,
            signer: _addr1,
            startTime: 1717734579,
            endTime: 1717734579,
            assets: new address[](0),
            values: new uint256[](0),
            makerSignature: new bytes(0)
        });

        bytes32 digest = sigUtils.getTypeDataHash(
            sigUtils.getStructHash(maker)
        );
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(pkMaker, digest);
        maker.makerSignature = sigUtils.combineSignature(v, r, s);

        (v, r, s) = vm.sign(pkTaker, digest);

        bytes memory takerSignature = sigUtils.combineSignature(v, r, s);

        OrderStructs.Taker memory taker = OrderStructs.Taker({
            recipient: _addr2,
            takerSignature: takerSignature
        });

        vm.prank(_addr2);
        weth.deposit{value: 0.1 ether}();
        l3Exchange.executeOrder(maker, taker);
    }

    function testExecuteAskNativeERC6551() public {
        // setup asset and values
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(erc721Sample);
        uint256[] memory assetValues = new uint256[](1);
        assetValues[0] = 2;

        assertEq(erc721Sample.ownerOf(2), _tba);

        // create maker order
        OrderStructs.Maker memory maker = OrderStructs.Maker({
            quoteType: QuoteType.Ask,
            orderNonce: 0,
            collectionType: CollectionType.ERC6551,
            collection: address(erc721Sample),
            tokenId: 1,
            amount: 0,
            currency: 0x0000000000000000000000000000000000000000,
            price: 0.1 ether,
            signer: _addr1,
            startTime: 1717734579,
            endTime: 1717734579,
            assets: assetAddresses,
            values: assetValues,
            makerSignature: new bytes(0)
        });

        // sign maker order
        bytes32 digest = sigUtils.getTypeDataHash(
            sigUtils.getStructHash(maker)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pkMaker, digest);

        maker.makerSignature = sigUtils.combineSignature(v, r, s);
        OrderStructs.Taker memory taker = OrderStructs.Taker({
            recipient: _addr2,
            takerSignature: new bytes(0)
        });

        // execute order
        l3Exchange.executeOrder{value: 0.1 ether}(maker, taker);
    }

    function testExecuteAskNativeERC1155() public {
        OrderStructs.Maker memory maker = OrderStructs.Maker({
            quoteType: QuoteType.Ask,
            orderNonce: 0,
            collectionType: CollectionType.ERC1155,
            collection: address(erc1155Sample),
            tokenId: 1,
            amount: 1,
            currency: 0x0000000000000000000000000000000000000000,
            price: 0.1 ether,
            signer: _addr1,
            startTime: 1717734579,
            endTime: 1717734579,
            assets: new address[](0),
            values: new uint256[](0),
            makerSignature: new bytes(0)
        });
        bytes32 digest = sigUtils.getTypeDataHash(
            sigUtils.getStructHash(maker)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pkMaker, digest);

        maker.makerSignature = sigUtils.combineSignature(v, r, s);
        OrderStructs.Taker memory taker = OrderStructs.Taker({
            recipient: _addr2,
            takerSignature: new bytes(0)
        });
        // vm.prank(_addr2);
        l3Exchange.executeOrder{value: 0.1 ether}(maker, taker);
    }
}
