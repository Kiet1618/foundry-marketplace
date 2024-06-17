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
