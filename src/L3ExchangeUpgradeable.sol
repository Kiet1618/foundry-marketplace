// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

// External
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";

// Internal
import {AccountRegistryUpgradeable} from "./internals/AccountRegistryUpgradeable.sol";
import {CurrencyManager} from "./internals/CurrencyManager.sol";
import {FeeManager} from "./internals/FeeManager.sol";
import {NonceManager} from "./internals/NonceManager.sol";
import {WrappedNativeReceiver} from "./internals/WrappedNativeReceiver.sol";

// Interfaces
import {IL3Exchange} from "./interfaces/IL3Exchange.sol";
import {IWNative} from "./interfaces/IWNative.sol";
import {IERC6551Registry} from "./interfaces/IERC6551Registry.sol";

// Libraries
import {OrderStructs} from "./libraries/OrderStructs.sol";

// Enums
import {QuoteType} from "./enums/QuoteType.sol";
import {CollectionType} from "./enums/CollectionType.sol";

// Constants
import {NATIVE_TOKEN, WRAP_NATIVE} from "./constants/AddressConstants.sol";
import {LibRoles} from "./constants/RoleConstants.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

// For debugging

import {console} from "forge-std/console.sol";

/**
 * @author L3 team (💕)
 */

contract L3ExchangeUpgradeable is
    IL3Exchange,
    Initializable,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    AccountRegistryUpgradeable,
    CurrencyManager,
    NonceManager,
    EIP712Upgradeable,
    FeeManager,
    ReentrancyGuardUpgradeable,
    WrappedNativeReceiver
{
    using OrderStructs for OrderStructs.Maker;

    bytes32 public DOMAIN_SEPARATOR;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory name_,
        string memory version_,
        address admin_,
        address operator_,
        address collection721_,
        address collection1155_,
        address registry_,
        address implementation_
    ) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __EIP712_init(name_, version_);
        __AccountRegistryUpgradeable_init(
            IERC6551Registry(registry_),
            implementation_
        );

        bytes32 operatorRole = LibRoles.OPERATOR_ROLE;
        bytes32 currencyRole = LibRoles.CURRENCY_ROLE;
        bytes32 collectionRole = LibRoles.COLLECTION_ROLE;

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(operatorRole, operator_);

        _grantRole(currencyRole, address(0));
        _grantRole(collectionRole, collection721_);
        _grantRole(collectionRole, collection1155_);

        _setRoleAdmin(currencyRole, operatorRole);
        _setRoleAdmin(collectionRole, operatorRole);

        DOMAIN_SEPARATOR = _domainSeparatorV4();
    }

    function executeOrderAskMultiple(
        OrderStructs.Maker[] calldata makers_,
        OrderStructs.Taker calldata taker_
    ) external payable override asAsk(makers_) {
        uint256 sumAmountNative;
        for (uint256 i = 0; i < makers_.length; i++) {
            bytes32 makerHash = OrderStructs.hash(makers_[i]);
            sumAmountNative += _executeOrder(makers_[i], taker_, makerHash, i);
        }
        _receiveNative(sumAmountNative);
    }

    function executeOrderBid(
        OrderStructs.Maker calldata maker_,
        OrderStructs.Taker calldata taker_
    ) external payable override asBid(maker_) {
        OrderStructs.Item[] memory items = new OrderStructs.Item[](
            taker_.index[0].length
        );
        for (uint256 i = 0; i < taker_.index[0].length; i++) {
            items[i] = maker_.items[taker_.index[0][i]];
        }
        OrderStructs.Maker memory takerRawSign = OrderStructs.Maker(
            maker_.quoteType,
            items,
            maker_.currency,
            maker_.signer,
            maker_.makerSignature
        );
        bytes32 takerHash = OrderStructs.hash(takerRawSign);
        bytes32 makerHash = OrderStructs.hash(maker_);
        address currency = maker_.currency;
        if (maker_.quoteType == QuoteType.Bid) {
            _validateSignature(
                taker_.recipient,
                takerHash,
                taker_.takerSignature
            );
            if (currency == address(0)) currency = WRAP_NATIVE;
        }
        _executeOrder(maker_, taker_, makerHash, 0);
        if (maker_.currency == NATIVE_TOKEN) {
            _receiveNative(maker_.items[0].price);
        }
    }

    function _executeOrder(
        OrderStructs.Maker calldata maker_,
        OrderStructs.Taker calldata taker_,
        bytes32 makerHash,
        uint256 index_
    ) internal nonReentrant returns (uint256) {
        uint256 sumAmount = 0;
        // Check the maker ask order

        _validateBasicOrderInfo(maker_);

        _validateSignature(maker_.signer, makerHash, maker_.makerSignature);
        console.logUint(taker_.index[index_].length);
        for (uint256 i = 0; i < taker_.index[index_].length; i++) {
            _setUsed(
                maker_.signer,
                maker_.items[taker_.index[index_][i]].orderNonce
            );
            if (maker_.currency == NATIVE_TOKEN) {
                sumAmount += maker_.items[taker_.index[index_][i]].price;
            }
            _validateAssetsInsideAccount(
                maker_.items[taker_.index[index_][i]].collection,
                maker_.items[taker_.index[index_][i]].tokenId,
                maker_.items[taker_.index[index_][i]].assets,
                maker_.items[taker_.index[index_][i]].values
            );

            if (
                maker_.items[taker_.index[index_][i]].collectionType ==
                CollectionType.ERC1155
            ) {
                _validateAmountERC1155(
                    maker_.items[taker_.index[index_][i]].collection,
                    maker_.signer,
                    maker_.items[taker_.index[index_][i]].tokenId,
                    maker_.items[taker_.index[index_][i]].amount
                );
            }
            _transferFeesAndFunds(
                maker_.currency,
                taker_.recipient,
                maker_.signer,
                maker_.items[taker_.index[index_][i]].price
            );

            _transferNonFungibleToken(
                maker_.items[taker_.index[index_][i]].collection,
                maker_.signer,
                taker_.recipient,
                maker_.items[taker_.index[index_][i]].tokenId,
                maker_.items[taker_.index[index_][i]].amount
            );

            emit OrderExecuted(
                maker_.quoteType,
                maker_.items[taker_.index[index_][i]].orderNonce,
                maker_.items[taker_.index[index_][i]].collectionType,
                maker_.items[taker_.index[index_][i]].collection,
                maker_.items[taker_.index[index_][i]].tokenId,
                maker_.currency,
                maker_.items[taker_.index[index_][i]].price,
                maker_.signer,
                taker_.recipient
            );
        }
        return sumAmount;
    }

    /**
     * @notice Transfer fees and funds to protocol recipient, and seller
     * @param currency_ currency being used for the purchase (e.g., WETH/USDC)
     * @param from_ sender of the funds
     * @param to_ seller's recipient
     * @param amount_ amount being transferred (in currency)
     */
    function _transferFeesAndFunds(
        address currency_,
        address from_,
        address to_,
        uint256 amount_
    ) internal {
        // Initialize the final amount that is transferred to seller
        // 1. Protocol fee calculation
        uint256 fee = (amount_ * _protocolFee) / 10000;
        uint256 finalSellerAmount = amount_ - fee;
        // 2. Transfer final amount (post-fees) to seller
        if (currency_ == WRAP_NATIVE) {
            _transferCurrency(currency_, from_, address(this), amount_);
            IWNative(WRAP_NATIVE).withdraw(amount_);
            _transferCurrency(
                NATIVE_TOKEN,
                address(this),
                to_,
                finalSellerAmount
            );
            _transferCurrency(
                NATIVE_TOKEN,
                address(this),
                _protocolFeeRecipient,
                fee
            );
        } else {
            _transferCurrency(currency_, from_, to_, finalSellerAmount);
            _transferCurrency(currency_, from_, _protocolFeeRecipient, fee);
        }
    }

    /**
     * @notice Verify the validity of the maker order
     * @param makerAsk maker order
     */
    function _validateBasicOrderInfo(
        OrderStructs.Maker calldata makerAsk
    ) private view {
        for (uint256 i = 0; i < makerAsk.items.length; i++) {
            // Check if the price is zero
            if (makerAsk.items[i].price == 0) revert Exchange__ZeroValue();

            // Check if the order is within the time range
            if (
                makerAsk.items[i].startTime > block.timestamp ||
                makerAsk.items[i].endTime < block.timestamp
            ) revert Exchange__OutOfRange();

            // Check if the collection is valid
            if (
                !hasRole(LibRoles.COLLECTION_ROLE, makerAsk.items[i].collection)
            ) revert Exchange__InvalidCollection();

            // Check if the nonce is valid
            if (makerAsk.items[i].orderNonce < _minNonce[makerAsk.signer])
                revert Exchange__InvalidNonce();

            // Check if the nonce is valid
            if (_isUsed(makerAsk.signer, makerAsk.items[i].orderNonce))
                revert Exchange__InvalidNonce();
        }
        if (!hasRole(LibRoles.CURRENCY_ROLE, makerAsk.currency))
            revert Exchange__InvalidCurrency();
    }

    function _validateSignature(
        address signer_,
        bytes32 hash_,
        bytes calldata signature_
    ) internal view {
        bytes32 digest = _hashTypedDataV4(hash_);

        (address recoveredAddress, , ) = ECDSA.tryRecover(digest, signature_);

        // Verify the validity of the signature
        if (recoveredAddress == address(0) || recoveredAddress != signer_)
            revert Exchange__InvalidSigner();
    }

    function _validateAssetsInsideAccount(
        address collection,
        uint256 tokenId,
        address[] calldata assets,
        uint256[] calldata values
    ) internal view {
        address erc6551Account = _registry.account(
            _implementation,
            block.chainid,
            collection,
            tokenId,
            0
        );
        uint256 length = assets.length;
        if (length != values.length) revert Exchange__LengthMisMatch();

        for (uint256 i = 0; i < length; ) {
            if (erc6551Account != _safeOwnerOf(assets[i], values[i])) {
                revert Exchange__InvalidAsset();
            }
            unchecked {
                ++i;
            }
        }
    }

    function _validateAmountERC1155(
        address collection,
        address from,
        uint256 tokenId,
        uint256 amount
    ) internal view {
        if (IERC1155(collection).balanceOf(from, tokenId) < amount)
            revert Exchange__InsufficientBalance();
    }

    /**
     * @notice Set the protocol fee
     * @param newProtocolFeeRecipient_ new protocol fee recipient
     * @param newProtocolFee_ new protocol fee
     */

    function setProtocolFee(
        address newProtocolFeeRecipient_,
        uint256 newProtocolFee_
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setProtocolFee(newProtocolFeeRecipient_, newProtocolFee_);
    }

    /* solhint-disable no-empty-blocks */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(LibRoles.UPGRADER_ROLE) {}

    modifier asBid(OrderStructs.Maker calldata maker_) {
        require(
            maker_.quoteType == QuoteType.Bid,
            "Exchange: Invalid quote type"
        );
        _;
    }

    modifier asAsk(OrderStructs.Maker[] calldata makers_) {
        for (uint256 i = 0; i < makers_.length; i++) {
            require(
                makers_[i].quoteType == QuoteType.Ask,
                "Exchange: Invalid quote type"
            );
        }
        _;
    }
}
