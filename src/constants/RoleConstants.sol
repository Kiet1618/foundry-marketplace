// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

library LibRoles {
    /// @dev value is equal to keccak256("SIGNER_ROLE")
    bytes32 public constant SIGNER_ROLE = 0xe2f4eaae4a9751e85a3e4a7b9587827a877f29914755229b07a7b2da98285f70;
    /// @dev value is equal to keccak256("PAUSER_ROLE")
    bytes32 public constant PAUSER_ROLE = 0x65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a;
    /// @dev value is equal to keccak256("MINTER_ROLE")
    bytes32 public constant MINTER_ROLE = 0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6;
    /// @dev value is equal to keccak256("OPERATOR_ROLE")
    bytes32 public constant OPERATOR_ROLE = 0x97667070c54ef182b0f5858b034beac1b6f3089aa2d3188bb1e8929f4fa9b929;
    /// @dev value is equal to keccak256("UPGRADER_ROLE")
    bytes32 public constant UPGRADER_ROLE = 0x189ab7a9244df0848122154315af71fe140f3db0fe014031783b0946b8c9d2e3;
    /// @dev value is equal to keccak256("TREASURER_ROLE")
    bytes32 public constant TREASURER_ROLE = 0x3496e2e73c4d42b75d702e60d9e48102720b8691234415963a5a857b86425d07;
    /// @dev value is equal to keccak256("CURRENCY_ROLE")
    bytes32 public constant CURRENCY_ROLE = 0xf05d08f52b65664f2d8334187e35158d45f068d9d83ac572adc3840604b088aa;
    /// @dev value is equal to keccak256("COLLECTION_ROLE")
    bytes32 public constant COLLECTION_ROLE = 0x40a5c770eee7730548a6335e1f372e76bf4759f6fda1a932bd9cfc33106f0b4c;
}
