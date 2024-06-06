// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { IERC721, ERC721Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {
    ERC721EnumerableUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";

contract ERC721Sample is
    Initializable,
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    UUPSUpgradeable,
    OwnableUpgradeable
{
    error BlockedAddress();

    uint256 private __nextTokenId;
    string public baseTokenURI;
    mapping(address => bool) public blacklistedAddress;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner_, string calldata name_, string calldata symbol_) public initializer {
        __ERC721_init_unchained(name_, symbol_);
        __Ownable_init_unchained(initialOwner_);
        __ERC721Enumerable_init_unchained();
        __UUPSUpgradeable_init_unchained();
    }

    function mint(address to_) public onlyOwner {
        uint256 tokenId = ++__nextTokenId;
        _safeMint(to_, tokenId);
    }

    function mintBulk(address[] calldata tos_) public onlyOwner {
        uint256 tokenId;
        for (uint256 i; i != tos_.length; ) {
            tokenId = ++__nextTokenId;
            _safeMint(tos_[i], tokenId);
            unchecked {
                ++i;
            }
        }
    }

    function mintSingleBulk(address to_, uint256 amount_) public onlyOwner {
        uint256 tokenId;
        for (uint256 i; i != amount_; ) {
            tokenId = ++__nextTokenId;
            _safeMint(to_, tokenId);
            unchecked {
                ++i;
            }
        }
    }

    function setBaseTokenURI(string calldata baseTokenURI_) external onlyOwner {
        baseTokenURI = baseTokenURI_;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721Upgradeable, ERC721EnumerableUpgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseTokenURI;
    }

    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) returns (address) {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(
        address account,
        uint128 value
    ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
        super._increaseBalance(account, value);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
