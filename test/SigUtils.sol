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
        0x50d3dece8643e89aa2715bc71becacd0b6b0c75104547e261fa913129a059891;

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
                        maker.amount,
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
