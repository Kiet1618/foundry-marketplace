// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { WRAP_NATIVE } from "../constants/AddressConstants.sol";

contract WrappedNativeReceiver {
    /**
     * @dev only accept WNative via fallback from the WNative contract
     */

    receive() external payable {
        assert(msg.sender == WRAP_NATIVE);
    }
}
