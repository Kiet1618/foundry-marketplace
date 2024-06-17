// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {Test} from "forge-std/Test.sol";

import {L3ExchangeUpgradeable} from "../src/L3ExchangeUpgradeable.sol";
import {ERC721Test} from "../src/ERC721Test.sol";
import {ERC1155Test} from "../src/ERC1155Test.sol";
import {WETH9} from "../src/WETH.sol";
import {ERC20Test} from "../src/ERC20Test.sol";

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
    uint256 pkMaker2 = 0x11;
    uint256 pkTaker2 = 0x14;
    uint256 pkFeeRecipient = 0x13;
    address addr1 = vm.addr(pkMaker);
    address addr2 = vm.addr(pkTaker);
    address addr3 = vm.addr(pkMaker2);
    address addr4 = vm.addr(pkTaker2);
    address feeRecipient = vm.addr(pkFeeRecipient);
    SigUtils sigUtils;
    address addrImplemention;
    address addrResgiter;
    IERC6551Registry erc6551Registry;
    address tba;
    ERC1155Test erc1155Sample;
    uint256 startTime = 1717734579;
    uint256 endTime = 1717734579;
    uint256 nonce = 0;
    uint256 price = 0.1 ether;
    ERC20Test erc20Sample;

    receive() external payable {}

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /* ----------- SETUP ------------ */

    function setUp() public {
        weth = new WETH9();

        address proxyERC20 = Upgrades.deployUUPSProxy(
            "ERC20Test.sol",
            abi.encodeCall(
                ERC20Test.initialize,
                (address(this), "ERC20Test", "TCOIN")
            )
        );

        erc20Sample = ERC20Test((proxyERC20));

        address proxyERC721 = Upgrades.deployUUPSProxy(
            "ERC721Test.sol",
            abi.encodeCall(
                ERC721Test.initialize,
                (address(this), "ERC721Test", "COL")
            )
        );

        erc721Sample = ERC721Test((proxyERC721));

        erc721Sample.mint(addr1);
        erc721Sample.mint(addr1);

        addrImplemention = 0x2D25602551487C3f3354dD80D76D54383A243358;
        addrResgiter = 0x02101dfB77FDE026414827Fdc604ddAF224F0921;

        erc6551Registry = IERC6551Registry(addrResgiter);

        tba = erc6551Registry.createAccount(
            addrImplemention,
            11155111,
            address(erc721Sample),
            1,
            0,
            abi.encodePacked()
        );

        erc721Sample.mint(addr3);

        erc721Sample.mint(address(this));
        erc721Sample.transferFrom(address(this), tba, 4);

        address proxyERC1155 = Upgrades.deployUUPSProxy(
            "ERC1155Test.sol",
            abi.encodeCall(ERC1155Test.initialize, ("ERC1155Test"))
        );

        erc1155Sample = ERC1155Test((proxyERC1155));

        erc1155Sample.mint(addr1, 1, 1, "");
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
        vm.prank(address(this));
        l3Exchange.setProtocolFee(feeRecipient, 1000);
        l3Exchange.grantRole(LibRoles.CURRENCY_ROLE, address(weth));
        l3Exchange.grantRole(LibRoles.CURRENCY_ROLE, address(erc20Sample));

        vm.prank(addr1);
        erc721Sample.setApprovalForAll(address(l3Exchange), true);
        vm.prank(addr1);
        erc1155Sample.setApprovalForAll(address(l3Exchange), true);
        vm.prank(addr3);
        erc721Sample.setApprovalForAll(address(l3Exchange), true);
        sigUtils = new SigUtils(l3Exchange.DOMAIN_SEPARATOR());

        erc20Sample.mint(addr2, 10 ether);

        vm.prank(addr2);
        erc20Sample.approve(address(l3Exchange), 10 ether);

        vm.prank(addr2);
        vm.deal(addr2, 10 ether);
        vm.deal(addr4, 10 ether);
        vm.warp(startTime);
    }

    /* ----------- TEST SETUP ------------ */

    // function test_Setup() public view {
    //     assertEq(erc721Sample.ownerOf(1), addr1);
    //     (address _protocolFeeRecipient, uint256 _protocolFee) = l3Exchange
    //         .viewProtocolFeeInfo();
    //     assertEq(_protocolFeeRecipient, feeRecipient);
    //     assertEq(_protocolFee, 1000);

    //     assertEq(
    //         l3Exchange.hasRole(LibRoles.CURRENCY_ROLE, address(weth)),
    //         true
    //     );

    //     assertEq(erc721Sample.ownerOf(4), tba);
    //     assertEq(erc1155Sample.balanceOf(addr1, 1), 1);
    // }

    /* ----------- CREATE ACCOUNT TBA ------------ */

    // function test_createAccountTBA() public view {
    //     address account = erc6551Registry.account(
    //         addrImplemention,
    //         11155111,
    //         address(erc721Sample),
    //         1,
    //         0
    //     );

    //     assertEq(account, tba);
    // }

    /* ----------- ASK NATIVE WITH TWO ITEM ------------ */

    // function testExecuteAskNativeTwoItem() public {
    //     OrderStructs.Item[] memory items = new OrderStructs.Item[](2);

    //     items[0] = OrderStructs.Item({
    //         collectionType: CollectionType.ERC721,
    //         orderNonce: nonce,
    //         collection: address(erc721Sample),
    //         tokenId: 1,
    //         amount: 0,
    //         assets: new address[](0),
    //         values: new uint256[](0),
    //         startTime: startTime,
    //         endTime: endTime,
    //         price: price
    //     });

    //     items[1] = OrderStructs.Item({
    //         collectionType: CollectionType.ERC721,
    //         orderNonce: nonce + 1,
    //         collection: address(erc721Sample),
    //         tokenId: 2,
    //         amount: 0,
    //         assets: new address[](0),
    //         values: new uint256[](0),
    //         startTime: startTime,
    //         endTime: endTime,
    //         price: price
    //     });

    //     OrderStructs.Maker memory maker = OrderStructs.Maker({
    //         quoteType: QuoteType.Ask,
    //         items: items,
    //         currency: address(0),
    //         signer: addr1,
    //         makerSignature: new bytes(0)
    //     });

    //     bytes32 digest = sigUtils.getTypeDataHash(OrderStructs.hash(maker));
    //     (uint8 v, bytes32 r, bytes32 s) = vm.sign(pkMaker, digest);

    //     maker.makerSignature = sigUtils.combineSignature(v, r, s);

    //     OrderStructs.Item memory item3 = OrderStructs.Item({
    //         collectionType: CollectionType.ERC721,
    //         collection: address(erc721Sample),
    //         orderNonce: nonce,
    //         tokenId: 3,
    //         amount: 0,
    //         assets: new address[](0),
    //         values: new uint256[](0),
    //         startTime: startTime,
    //         endTime: endTime,
    //         price: price
    //     });

    //     OrderStructs.Item[] memory items2 = new OrderStructs.Item[](1);
    //     items2[0] = item3;

    //     OrderStructs.Maker memory maker2 = OrderStructs.Maker({
    //         quoteType: QuoteType.Ask,
    //         items: items2,
    //         currency: address(0),
    //         signer: addr3,
    //         makerSignature: new bytes(0)
    //     });

    //     bytes32 digest2 = sigUtils.getTypeDataHash(OrderStructs.hash(maker2));
    //     (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(pkMaker2, digest2);

    //     maker2.makerSignature = sigUtils.combineSignature(v2, r2, s2);

    //     OrderStructs.Maker[] memory makerArray = new OrderStructs.Maker[](2);
    //     makerArray[0] = maker;
    //     makerArray[1] = maker2;

    //     uint256[][] memory index = new uint256[][](2);
    //     index[0] = new uint256[](1);
    //     index[0][0] = 1;
    //     index[1] = new uint256[](1);
    //     index[1][0] = 0;
    //     OrderStructs.Taker memory taker = OrderStructs.Taker({
    //         recipient: addr2,
    //         index: index,
    //         takerSignature: new bytes(0)
    //     });
    //     uint256 beforeBalanceFeeRecipient = feeRecipient.balance;
    //     uint256 beforeBalanceAddr1 = addr1.balance;
    //     uint256 beforeBalanceAddr3 = addr3.balance;

    //     vm.prank(addr2);

    //     l3Exchange.executeOrderAskMultiple{value: 0.2 ether}(makerArray, taker);
    //     assertEq(addr1.balance, beforeBalanceAddr1 + 0.09 ether);
    //     assertEq(feeRecipient.balance, beforeBalanceFeeRecipient + 0.02 ether);
    //     assertEq(addr3.balance, beforeBalanceAddr3 + 0.09 ether);
    //     assertEq(address(l3Exchange).balance, 0 ether);

    //     assertEq(erc721Sample.ownerOf(3), addr2);
    //     assertEq(erc721Sample.ownerOf(2), addr2);
    // }

    /* ----------- ASK NATIVE WITH TWO ITEM HAVE ONE 6551 ------------ */

    // function testExecuteAskNativeTwoItemHaveOneERC6551() public {
    //     OrderStructs.Item[] memory items = new OrderStructs.Item[](2);

    //     // setup asset and values
    //     address[] memory assetAddresses = new address[](1);
    //     assetAddresses[0] = address(erc721Sample);
    //     uint256[] memory assetValues = new uint256[](1);
    //     assetValues[0] = 4;

    //     items[0] = OrderStructs.Item({
    //         collectionType: CollectionType.ERC6551,
    //         collection: address(erc721Sample),
    //         orderNonce: nonce,
    //         tokenId: 1,
    //         amount: 0,
    //         assets: assetAddresses,
    //         values: assetValues,
    //         price: price,
    //         startTime: startTime,
    //         endTime: endTime
    //     });

    //     items[1] = OrderStructs.Item({
    //         collectionType: CollectionType.ERC721,
    //         collection: address(erc721Sample),
    //         orderNonce: nonce + 1,
    //         tokenId: 2,
    //         amount: 0,
    //         assets: new address[](0),
    //         values: new uint256[](0),
    //         price: price,
    //         startTime: startTime,
    //         endTime: endTime
    //     });

    //     OrderStructs.Maker memory maker = OrderStructs.Maker({
    //         quoteType: QuoteType.Ask,
    //         items: items,
    //         currency: address(0),
    //         signer: addr1,
    //         makerSignature: new bytes(0)
    //     });

    //     bytes32 digest = sigUtils.getTypeDataHash(OrderStructs.hash(maker));
    //     (uint8 v, bytes32 r, bytes32 s) = vm.sign(pkMaker, digest);

    //     maker.makerSignature = sigUtils.combineSignature(v, r, s);

    //     OrderStructs.Item memory item3 = OrderStructs.Item({
    //         collectionType: CollectionType.ERC721,
    //         orderNonce: nonce,
    //         collection: address(erc721Sample),
    //         tokenId: 3,
    //         amount: 0,
    //         assets: new address[](0),
    //         values: new uint256[](0),
    //         price: price,
    //         startTime: startTime,
    //         endTime: endTime
    //     });

    //     OrderStructs.Item[] memory items2 = new OrderStructs.Item[](1);
    //     items2[0] = item3;

    //     OrderStructs.Maker memory maker2 = OrderStructs.Maker({
    //         quoteType: QuoteType.Ask,
    //         items: items2,
    //         currency: address(0),
    //         signer: addr3,
    //         makerSignature: new bytes(0)
    //     });

    //     bytes32 digest2 = sigUtils.getTypeDataHash(OrderStructs.hash(maker2));
    //     (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(pkMaker2, digest2);

    //     maker2.makerSignature = sigUtils.combineSignature(v2, r2, s2);

    //     OrderStructs.Maker[] memory makerArray = new OrderStructs.Maker[](2);
    //     makerArray[0] = maker;
    //     makerArray[1] = maker2;

    //     uint256[][] memory index = new uint256[][](2);
    //     index[0] = new uint256[](1);
    //     index[0][0] = 1;
    //     index[1] = new uint256[](1);
    //     index[1][0] = 0;
    //     OrderStructs.Taker memory taker = OrderStructs.Taker({
    //         recipient: addr2,
    //         index: index,
    //         takerSignature: new bytes(0)
    //     });
    //     uint256 beforeBalanceFeeRecipient = feeRecipient.balance;
    //     uint256 beforeBalanceAddr1 = addr1.balance;
    //     uint256 beforeBalanceAddr3 = addr3.balance;

    //     vm.prank(addr2);
    //     l3Exchange.executeOrderAskMultiple{value: 0.2 ether}(makerArray, taker);
    //     assertEq(addr1.balance, beforeBalanceAddr1 + 0.09 ether);
    //     assertEq(feeRecipient.balance, beforeBalanceFeeRecipient + 0.02 ether);
    //     assertEq(addr3.balance, beforeBalanceAddr3 + 0.09 ether);
    //     assertEq(address(l3Exchange).balance, 0 ether);

    //     assertEq(erc721Sample.ownerOf(3), addr2);
    //     assertEq(erc721Sample.ownerOf(2), addr2);
    // }

    /* ----------- ASK NATIVE WITH TWO ITEAM HAVE ONE 1155 ------------ */

    // function testExecuteAskNativeTwoItemHaveOneERC1155() public {
    //     OrderStructs.Item[] memory items = new OrderStructs.Item[](2);
    //     items[0] = OrderStructs.Item({
    //         collectionType: CollectionType.ERC721,
    //         orderNonce: nonce,
    //         collection: address(erc721Sample),
    //         tokenId: 1,
    //         amount: 0,
    //         assets: new address[](0),
    //         values: new uint256[](0),
    //         price: price,
    //         startTime: startTime,
    //         endTime: endTime
    //     });

    //     items[1] = OrderStructs.Item({
    //         collectionType: CollectionType.ERC1155,
    //         orderNonce: nonce + 1,
    //         collection: address(erc1155Sample),
    //         tokenId: 1,
    //         amount: 1,
    //         assets: new address[](0),
    //         values: new uint256[](0),
    //         price: price,
    //         startTime: startTime,
    //         endTime: endTime
    //     });

    //     OrderStructs.Maker memory maker = OrderStructs.Maker({
    //         quoteType: QuoteType.Ask,
    //         items: items,
    //         currency: address(0),
    //         signer: addr1,
    //         makerSignature: new bytes(0)
    //     });

    //     bytes32 digest = sigUtils.getTypeDataHash(OrderStructs.hash(maker));
    //     (uint8 v, bytes32 r, bytes32 s) = vm.sign(pkMaker, digest);

    //     maker.makerSignature = sigUtils.combineSignature(v, r, s);

    //     OrderStructs.Item memory item3 = OrderStructs.Item({
    //         collectionType: CollectionType.ERC721,
    //         collection: address(erc721Sample),
    //         orderNonce: nonce,
    //         tokenId: 3,
    //         amount: 0,
    //         assets: new address[](0),
    //         values: new uint256[](0),
    //         price: price,
    //         startTime: startTime,
    //         endTime: endTime
    //     });

    //     OrderStructs.Item[] memory items2 = new OrderStructs.Item[](1);
    //     items2[0] = item3;

    //     OrderStructs.Maker memory maker2 = OrderStructs.Maker({
    //         quoteType: QuoteType.Ask,
    //         items: items2,
    //         currency: address(0),
    //         signer: addr3,
    //         makerSignature: new bytes(0)
    //     });

    //     bytes32 digest2 = sigUtils.getTypeDataHash(OrderStructs.hash(maker2));
    //     (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(pkMaker2, digest2);

    //     maker2.makerSignature = sigUtils.combineSignature(v2, r2, s2);

    //     OrderStructs.Maker[] memory makerArray = new OrderStructs.Maker[](2);
    //     makerArray[0] = maker;
    //     makerArray[1] = maker2;

    //     uint256[][] memory index = new uint256[][](2);
    //     index[0] = new uint256[](1);
    //     index[0][0] = 1;
    //     index[1] = new uint256[](1);
    //     index[1][0] = 0;
    //     OrderStructs.Taker memory taker = OrderStructs.Taker({
    //         recipient: addr2,
    //         index: index,
    //         takerSignature: new bytes(0)
    //     });
    //     uint256 beforeBalanceFeeRecipient = feeRecipient.balance;
    //     uint256 beforeBalanceAddr1 = addr1.balance;
    //     uint256 beforeBalanceAddr3 = addr3.balance;

    //     vm.prank(addr2);
    //     l3Exchange.executeOrderAskMultiple{value: 0.2 ether}(makerArray, taker);
    //     assertEq(addr1.balance, beforeBalanceAddr1 + 0.09 ether);
    //     assertEq(feeRecipient.balance, beforeBalanceFeeRecipient + 0.02 ether);
    //     assertEq(addr3.balance, beforeBalanceAddr3 + 0.09 ether);
    //     assertEq(address(l3Exchange).balance, 0 ether);

    //     assertEq(erc721Sample.ownerOf(3), addr2);
    //     assertEq(erc1155Sample.balanceOf(addr2, 1), 1);
    // }

    /* ----------- BID NATIVE ------------ */

    // function testExecuteBidNative() public {
    //     OrderStructs.Item[] memory items = new OrderStructs.Item[](2);

    //     items[0] = OrderStructs.Item({
    //         collectionType: CollectionType.ERC721,
    //         orderNonce: nonce,
    //         collection: address(erc721Sample),
    //         tokenId: 1,
    //         amount: 0,
    //         assets: new address[](0),
    //         values: new uint256[](0),
    //         price: price,
    //         startTime: startTime,
    //         endTime: endTime
    //     });

    //     items[1] = OrderStructs.Item({
    //         collectionType: CollectionType.ERC721,
    //         orderNonce: nonce + 1,
    //         collection: address(erc721Sample),
    //         tokenId: 2,
    //         amount: 0,
    //         assets: new address[](0),
    //         values: new uint256[](0),
    //         price: price,
    //         startTime: startTime,
    //         endTime: endTime
    //     });

    //     OrderStructs.Maker memory maker = OrderStructs.Maker({
    //         quoteType: QuoteType.Bid,
    //         items: items,
    //         currency: address(0),
    //         signer: addr1,
    //         makerSignature: new bytes(0)
    //     });

    //     bytes32 digest = sigUtils.getTypeDataHash(OrderStructs.hash(maker));
    //     (uint8 v, bytes32 r, bytes32 s) = vm.sign(pkMaker, digest);

    //     maker.makerSignature = sigUtils.combineSignature(v, r, s);

    //     uint256[][] memory index = new uint256[][](1);
    //     index[0] = new uint256[](1);
    //     index[0][0] = 0;

    //     OrderStructs.Item[] memory itemTakerBuy = new OrderStructs.Item[](1);
    //     itemTakerBuy[0] = items[0];

    //     OrderStructs.Maker memory takerTypeSign = OrderStructs.Maker({
    //         quoteType: QuoteType.Bid,
    //         items: itemTakerBuy,
    //         currency: address(0),
    //         signer: addr1,
    //         makerSignature: new bytes(0)
    //     });

    //     bytes32 digestTaker = sigUtils.getTypeDataHash(
    //         OrderStructs.hash(takerTypeSign)
    //     );
    //     (uint8 vTaker, bytes32 rTaker, bytes32 sTaker) = vm.sign(
    //         pkTaker,
    //         digestTaker
    //     );

    //     bytes memory takerSign = sigUtils.combineSignature(
    //         vTaker,
    //         rTaker,
    //         sTaker
    //     );

    //     OrderStructs.Taker memory taker = OrderStructs.Taker({
    //         recipient: addr2,
    //         index: index,
    //         takerSignature: takerSign
    //     });
    //     uint256 beforeBalanceFeeRecipient = feeRecipient.balance;
    //     uint256 beforeBalanceAddr1 = addr1.balance;

    //     vm.prank(addr2);
    //     l3Exchange.executeOrderBid{value: 0.1 ether}(maker, taker);

    //     assertEq(addr1.balance, beforeBalanceAddr1 + 0.09 ether);
    //     assertEq(feeRecipient.balance, beforeBalanceFeeRecipient + 0.01 ether);

    //     assertEq(erc721Sample.ownerOf(1), addr2);
    // }

    /* ----------- ASK ERC20 WITH TWO ITEM ------------ */

    // function testExecuteAskERC20TwoItem() public {
    //     OrderStructs.Item[] memory items = new OrderStructs.Item[](2);

    //     items[0] = OrderStructs.Item({
    //         collectionType: CollectionType.ERC721,
    //         collection: address(erc721Sample),
    //         orderNonce: nonce,
    //         tokenId: 1,
    //         amount: 0,
    //         assets: new address[](0),
    //         values: new uint256[](0),
    //         price: 1 ether,
    //         startTime: startTime,
    //         endTime: endTime
    //     });

    //     items[1] = OrderStructs.Item({
    //         collectionType: CollectionType.ERC721,
    //         orderNonce: nonce + 1,
    //         collection: address(erc721Sample),
    //         tokenId: 2,
    //         amount: 0,
    //         assets: new address[](0),
    //         values: new uint256[](0),
    //         price: 1 ether,
    //         startTime: startTime,
    //         endTime: endTime
    //     });

    //     OrderStructs.Maker memory maker = OrderStructs.Maker({
    //         quoteType: QuoteType.Ask,
    //         items: items,
    //         currency: address(erc20Sample),
    //         signer: addr1,
    //         makerSignature: new bytes(0)
    //     });

    //     bytes32 digest = sigUtils.getTypeDataHash(OrderStructs.hash(maker));
    //     (uint8 v, bytes32 r, bytes32 s) = vm.sign(pkMaker, digest);

    //     maker.makerSignature = sigUtils.combineSignature(v, r, s);

    //     OrderStructs.Item memory item3 = OrderStructs.Item({
    //         collectionType: CollectionType.ERC721,
    //         collection: address(erc721Sample),
    //         orderNonce: nonce,
    //         tokenId: 3,
    //         amount: 0,
    //         assets: new address[](0),
    //         values: new uint256[](0),
    //         price: price,
    //         startTime: startTime,
    //         endTime: endTime
    //     });

    //     OrderStructs.Item[] memory items2 = new OrderStructs.Item[](1);
    //     items2[0] = item3;

    //     OrderStructs.Maker memory maker2 = OrderStructs.Maker({
    //         quoteType: QuoteType.Ask,
    //         items: items2,
    //         currency: address(0),
    //         signer: addr3,
    //         makerSignature: new bytes(0)
    //     });

    //     bytes32 digest2 = sigUtils.getTypeDataHash(OrderStructs.hash(maker2));
    //     (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(pkMaker2, digest2);

    //     maker2.makerSignature = sigUtils.combineSignature(v2, r2, s2);

    //     OrderStructs.Maker[] memory makerArray = new OrderStructs.Maker[](2);
    //     makerArray[0] = maker;
    //     makerArray[1] = maker2;

    //     uint256[][] memory index = new uint256[][](2);
    //     index[0] = new uint256[](1);
    //     index[0][0] = 0;
    //     index[1] = new uint256[](1);
    //     index[1][0] = 0;
    //     OrderStructs.Taker memory taker = OrderStructs.Taker({
    //         recipient: addr2,
    //         index: index,
    //         takerSignature: new bytes(0)
    //     });
    //     uint256 beforeBalanceFeeRecipient = feeRecipient.balance;
    //     uint256 beforeBalanceAddr3 = addr3.balance;

    //     vm.prank(addr2);
    //     l3Exchange.executeOrderAskMultiple{value: 0.1 ether}(makerArray, taker);
    //     assertEq(feeRecipient.balance, beforeBalanceFeeRecipient + 0.01 ether);
    //     assertEq(addr3.balance, beforeBalanceAddr3 + 0.09 ether);
    //     assertEq(address(l3Exchange).balance, 0 ether);
    //     assertEq(erc20Sample.balanceOf(addr1), 0.9 ether);
    //     assertEq(erc20Sample.balanceOf(addr2), 9 ether);
    //     assertEq(erc721Sample.ownerOf(3), addr2);
    //     assertEq(erc721Sample.ownerOf(1), addr2);
    // }

    /* -----------  BID ERC20 ------------ */

    // function testExecuteBidERC20() public {
    //     OrderStructs.Item[] memory items = new OrderStructs.Item[](2);

    //     items[0] = OrderStructs.Item({
    //         collectionType: CollectionType.ERC721,
    //         collection: address(erc721Sample),
    //         orderNonce: nonce,
    //         tokenId: 1,
    //         amount: 0,
    //         assets: new address[](0),
    //         values: new uint256[](0),
    //         price: 1 ether,
    //         startTime: startTime,
    //         endTime: endTime
    //     });

    //     items[1] = OrderStructs.Item({
    //         collectionType: CollectionType.ERC721,
    //         collection: address(erc721Sample),
    //         orderNonce: nonce + 1,
    //         tokenId: 2,
    //         amount: 0,
    //         assets: new address[](0),
    //         values: new uint256[](0),
    //         price: 1 ether,
    //         startTime: startTime,
    //         endTime: endTime
    //     });

    //     OrderStructs.Maker memory maker = OrderStructs.Maker({
    //         quoteType: QuoteType.Bid,
    //         items: items,
    //         currency: address(erc20Sample),
    //         signer: addr1,
    //         makerSignature: new bytes(0)
    //     });

    //     bytes32 digest = sigUtils.getTypeDataHash(OrderStructs.hash(maker));
    //     (uint8 v, bytes32 r, bytes32 s) = vm.sign(pkMaker, digest);

    //     maker.makerSignature = sigUtils.combineSignature(v, r, s);

    //     uint256[][] memory index = new uint256[][](1);
    //     index[0] = new uint256[](1);
    //     index[0][0] = 0;

    //     OrderStructs.Item[] memory itemTakerBuy = new OrderStructs.Item[](1);
    //     itemTakerBuy[0] = items[0];

    //     OrderStructs.Maker memory takerTypeSign = OrderStructs.Maker({
    //         quoteType: QuoteType.Bid,
    //         items: itemTakerBuy,
    //         currency: address(erc20Sample),
    //         signer: addr1,
    //         makerSignature: new bytes(0)
    //     });

    //     bytes32 digestTaker = sigUtils.getTypeDataHash(
    //         OrderStructs.hash(takerTypeSign)
    //     );
    //     (uint8 vTaker, bytes32 rTaker, bytes32 sTaker) = vm.sign(
    //         pkTaker,
    //         digestTaker
    //     );

    //     bytes memory takerSign = sigUtils.combineSignature(
    //         vTaker,
    //         rTaker,
    //         sTaker
    //     );

    //     OrderStructs.Taker memory taker = OrderStructs.Taker({
    //         recipient: addr2,
    //         index: index,
    //         takerSignature: takerSign
    //     });

    //     vm.prank(addr2);
    //     l3Exchange.executeOrderBid(maker, taker);

    //     assertEq(erc20Sample.balanceOf(addr1), 0.9 ether);
    //     assertEq(erc20Sample.balanceOf(addr2), 9 ether);
    //     assertEq(erc20Sample.balanceOf(feeRecipient), 0.1 ether);

    //     assertEq(erc721Sample.ownerOf(1), addr2);
    // }

    /* ----------- ASK NATIVE WITH TWO ITEM AND TWO BUYER ------------ */

    function testExecuteAskNativeTwoItemTwoBuyer() public {
        OrderStructs.Item[] memory items = new OrderStructs.Item[](2);

        items[0] = OrderStructs.Item({
            collectionType: CollectionType.ERC721,
            collection: address(erc721Sample),
            orderNonce: nonce,
            tokenId: 1,
            amount: 0,
            assets: new address[](0),
            values: new uint256[](0),
            price: price,
            startTime: startTime,
            endTime: endTime
        });

        items[1] = OrderStructs.Item({
            collectionType: CollectionType.ERC721,
            collection: address(erc721Sample),
            orderNonce: nonce + 1,
            tokenId: 2,
            amount: 0,
            assets: new address[](0),
            values: new uint256[](0),
            price: price,
            startTime: startTime,
            endTime: endTime
        });

        OrderStructs.Maker memory maker = OrderStructs.Maker({
            quoteType: QuoteType.Ask,
            items: items,
            currency: address(0),
            signer: addr1,
            makerSignature: new bytes(0)
        });

        bytes32 digest = sigUtils.getTypeDataHash(OrderStructs.hash(maker));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pkMaker, digest);

        maker.makerSignature = sigUtils.combineSignature(v, r, s);

        OrderStructs.Item memory item3 = OrderStructs.Item({
            collectionType: CollectionType.ERC721,
            collection: address(erc721Sample),
            orderNonce: nonce,
            tokenId: 3,
            amount: 0,
            assets: new address[](0),
            values: new uint256[](0),
            price: price,
            startTime: startTime,
            endTime: endTime
        });

        OrderStructs.Item[] memory items2 = new OrderStructs.Item[](1);
        items2[0] = item3;

        OrderStructs.Maker memory maker2 = OrderStructs.Maker({
            quoteType: QuoteType.Ask,
            items: items2,
            currency: address(0),
            signer: addr3,
            makerSignature: new bytes(0)
        });

        bytes32 digest2 = sigUtils.getTypeDataHash(OrderStructs.hash(maker2));
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(pkMaker2, digest2);

        maker2.makerSignature = sigUtils.combineSignature(v2, r2, s2);

        OrderStructs.Maker[] memory makerArray = new OrderStructs.Maker[](2);
        makerArray[0] = maker;
        makerArray[1] = maker2;

        uint256[][] memory index = new uint256[][](2);
        index[0] = new uint256[](1);
        index[0][0] = 0;
        index[1] = new uint256[](1);
        index[1][0] = 0;
        OrderStructs.Taker memory taker = OrderStructs.Taker({
            recipient: addr2,
            index: index,
            takerSignature: new bytes(0)
        });
        uint256 beforeBalanceFeeRecipient = feeRecipient.balance;
        uint256 beforeBalanceAddr1 = addr1.balance;
        uint256 beforeBalanceAddr3 = addr3.balance;

        vm.prank(addr2);
        l3Exchange.executeOrderAskMultiple{value: 0.2 ether}(makerArray, taker);
        assertEq(addr1.balance, beforeBalanceAddr1 + 0.09 ether);
        assertEq(feeRecipient.balance, beforeBalanceFeeRecipient + 0.02 ether);
        assertEq(addr3.balance, beforeBalanceAddr3 + 0.09 ether);
        assertEq(address(l3Exchange).balance, 0 ether);

        assertEq(erc721Sample.ownerOf(3), addr2);
        assertEq(erc721Sample.ownerOf(1), addr2);

        // BUYER 2
        uint256[][] memory index2 = new uint256[][](1);
        index2[0] = new uint256[](1);
        index2[0][0] = 1;

        OrderStructs.Taker memory taker2 = OrderStructs.Taker({
            recipient: addr4,
            index: index2,
            takerSignature: new bytes(0)
        });
        OrderStructs.Maker[] memory makerArray2 = new OrderStructs.Maker[](1);
        makerArray2[0] = maker;

        l3Exchange.executeOrderAskMultiple{value: 0.1 ether}(
            makerArray2,
            taker2
        );

        assertEq(erc721Sample.ownerOf(2), addr4);
    }
}
