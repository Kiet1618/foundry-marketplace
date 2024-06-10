// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {QuoteType} from "../src/enums/QuoteType.sol";
import {CollectionType} from "../src/enums/CollectionType.sol";
import {OrderStructs} from "../src/libraries/OrderStructs.sol";

contract SigUtils {
    bytes32 internal DOMAIN_SEPARATOR;

    constructor(bytes32 domainSeparator) {
        DOMAIN_SEPARATOR = domainSeparator;
    }

    bytes32 public constant _MAKER_TYPEHASH =
        0x5f3e890c36d263fd3e4b97d606b6456effba4409d05897000409303ba8dcf2f4;

    function getStructHash(
        OrderStructs.Maker memory maker
    ) public pure returns (bytes32) {
        return
            keccak256(
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
    }

    function getTypeDataHash(bytes32 structHash) public view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
            );
    }

    function combineSignature(
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public pure returns (bytes memory) {
        return abi.encodePacked(r, s, v);
    }
}
