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

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory name_,
        string memory version_,
        address admin_,
        address operator_,
        address collection_,
        address registry_,
        address implementation_
    ) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __EIP712_init(name_, version_);

        bytes32 operatorRole = LibRoles.OPERATOR_ROLE;
        bytes32 currencyRole = LibRoles.CURRENCY_ROLE;
        bytes32 collectionRole = LibRoles.COLLECTION_ROLE;

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(operatorRole, operator_);

        _grantRole(currencyRole, address(0));
        _grantRole(collectionRole, collection_);

        _setRoleAdmin(currencyRole, operatorRole);
        _setRoleAdmin(collectionRole, operatorRole);
    }

    /**
     * @inheritdoc IL3Exchange
     */
    function executeOrder(
        OrderStructs.Maker calldata maker_,
        OrderStructs.Taker calldata taker_
    ) external payable override nonReentrant {
        bytes32 makerHash = maker_.hash();
        address currency = maker_.currency;

        // Check the maker ask order
        _validateBasicOrderInfo(maker_);

        _validateSignature(maker_.signer, makerHash, maker_.makerSignature);

        if (maker_.collectionType == CollectionType.ERC6551) {
            _validateAssetsInsideAccount(
                maker_.collection,
                maker_.tokenId,
                maker_.assets,
                maker_.values
            );
        }

        // prevents replay
        _setUsed(maker_.signer, maker_.orderNonce);

        if (maker_.quoteType == QuoteType.Bid) {
            _validateSignature(
                taker_.recipient,
                makerHash,
                taker_.takerSignature
            );
            if (currency == address(0)) currency = WRAP_NATIVE;
        }

        // Execute transfer currency
        _transferFeesAndFunds(
            currency,
            taker_.recipient,
            maker_.signer,
            maker_.price
        );

        // Execute transfer token collection
        _transferNonFungibleToken(
            maker_.collection,
            maker_.signer,
            taker_.recipient,
            maker_.tokenId
        );

        emit OrderExecuted(
            maker_.quoteType,
            maker_.orderNonce,
            maker_.collectionType,
            maker_.collection,
            maker_.tokenId,
            maker_.currency,
            maker_.price,
            maker_.signer,
            taker_.recipient
        );
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
        if (currency_ == NATIVE_TOKEN) _receiveNative(amount_);
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
        // Verify the price is not 0
        if (makerAsk.price == 0) revert Exchange__ZeroValue();

        // Verify order timestamp
        if (
            makerAsk.startTime > block.timestamp ||
            makerAsk.endTime < block.timestamp
        ) revert Exchange__OutOfRange();

        // Verify whether the currency is whitelisted
        if (!hasRole(LibRoles.CURRENCY_ROLE, makerAsk.currency))
            revert Exchange__InvalidCurrency();

        if (!hasRole(LibRoles.COLLECTION_ROLE, makerAsk.collection))
            revert Exchange__InvalidCollection();

        // Verify whether order nonce has expired
        if (makerAsk.orderNonce < _minNonce[makerAsk.signer])
            revert Exchange__InvalidNonce();

        if (_isUsed(makerAsk.signer, makerAsk.orderNonce))
            revert Exchange__InvalidNonce();
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
}
