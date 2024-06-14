// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Libraries
import {OrderStructs} from "../libraries/OrderStructs.sol";
import {CollectionType} from "../enums/CollectionType.sol";
import {QuoteType} from "../enums/QuoteType.sol";

/**
 * @title IL3Exchange
 * @author L3 team
 */

interface IL3Exchange {
    error Exchange__ZeroValue();
    error Exchange__OutOfRange();
    error Exchange__InvalidNonce();
    error Exchange__InvalidCurrency();
    error Exchange__InvalidCollection();
    error Exchange__InvalidSigner();
    error Exchange__InvalidAsset();
    error Exchange__LengthMisMatch();
    error Exchange__InsufficientBalance();

    /**
     * @notice
     * Auction: allows a user to execute a taker ask (against a maker bid)
     * The bid price represents the maximum price that a buyer is willing to pay for security
     *
     * Exchange: function allows a user to execute a taker bid (against a maker ask)
     * The ask price represents the minimum price that a seller is willing to take for that same security
     * @param maker Taker struct
     * @param taker Maker struct
     */
    function executeOrder(
        OrderStructs.Maker calldata maker,
        OrderStructs.Taker calldata taker,
        uint256 index
    ) external payable;

    event OrderExecuted(
        QuoteType quoteType,
        uint256 orderNonce,
        CollectionType collectionType,
        address collection,
        uint256 tokenId,
        address currency,
        uint256 price,
        address seller,
        address recipient
    );

    function setProtocolFee(
        address newProtocolFeeRecipient_,
        uint256 newProtocolFee_
    ) external;
}
