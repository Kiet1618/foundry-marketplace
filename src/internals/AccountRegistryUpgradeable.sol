// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { LibRoles } from "../constants/RoleConstants.sol";
import { IERC6551Registry } from "../interfaces/IERC6551Registry.sol";

contract AccountRegistryUpgradeable is Initializable, AccessControlUpgradeable {
    IERC6551Registry internal _registry;
    address internal _implementation;

    function __AccountRegistryUpgradeable_init(
        IERC6551Registry registry_,
        address implementation_
    ) internal onlyInitializing {
        __AccountRegistryUpgradeable_init_unchained(registry_, implementation_);
    }

    function __AccountRegistryUpgradeable_init_unchained(
        IERC6551Registry registry_,
        address implementation_
    ) internal onlyInitializing {
        _setRegistryInfo(registry_, implementation_);
    }

    function _setRegistryInfo(IERC6551Registry registry_, address implementation_) internal {
        _registry = registry_;
        _implementation = implementation_;
    }

    function setRegistryInfo(
        IERC6551Registry registry_,
        address implementation_
    ) external onlyRole(LibRoles.OPERATOR_ROLE) {
        _setRegistryInfo(registry_, implementation_);
    }

    uint256[48] private __gap;
}
