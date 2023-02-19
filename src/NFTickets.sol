// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Owned } from "./../lib/solmate.git/src/auth/Owned.sol";
import { MerkleProofLib } from "./../lib/solmate.git/src/utils/MerkleProofLib.sol";
import { ERC1155 } from "./../lib/solmate.git/src/tokens/ERC1155.sol";

import { Initializable } from "./../lib/openzeppelin-contracts.git/contracts/proxy/utils/Initializable.sol";
import { Pausable } from "./../lib/openzeppelin-contracts.git/contracts/security/Pausable.sol";

import { LibString } from "./../lib/solady.git/src/utils/LibString.sol";

import { NFTicketsFactory } from "./NFTicketsFactory.sol";

contract NFTickets is Initializable, ERC1155, Pausable {
    error ImproperProof();
    error AlreadyClaimed(uint256 alreadyClaimed);
    error EventAlreadyStarted();
    error TooBigTokenId();

    event OwnershipTransferred(address indexed user, address indexed newOwner);
    event SetStartDate(uint256 indexed startDate_);
    event SetMerkleRoot(bytes32 indexed merkleRoot_);
    event SetRoleIds(uint256 indexed tokenId_, uint256[] roleIds_);
    event SetMaxTokenId(uint256 indexed maxTokenId_);

    mapping(address user => mapping(uint256 tokenId => uint256 numberClaimed))
        public tokensClaimed;
    mapping(uint256 tokenId => uint256[] roleIds) private _roleIds;

    uint256 private constant DEFAULT_MAX_TOKEN_ID = 32;

    address public owner;
    address public factory;
    uint256 public startDate;
    uint256 public maxTokenId;
    bytes32 public merkleRoot;

    modifier onlyOwner() {
        require(msg.sender == owner, "UNAUTHORIZED");

        _;
    }

    function initialize(
        address owner_,
        uint256 startDate_
    ) external initializer {
        owner = owner_;
        emit OwnershipTransferred(address(0), owner_);

        factory = msg.sender;
        startDate = startDate_;

        maxTokenId = DEFAULT_MAX_TOKEN_ID;
    }

    /// @dev Claim function ordinary callled by user through our app
    function claim(
        bytes32[] calldata merkleProof,
        uint256 tokenId,
        uint256 amount
    ) external whenNotPaused {
        if (maxTokenId <= tokenId) {
            revert TooBigTokenId();
        }

        if (block.timestamp > startDate) {
            revert EventAlreadyStarted();
        }

        // double hash to prevent second preimage attack
        bytes32 leaf = keccak256(
            bytes.concat(keccak256(abi.encode(msg.sender, tokenId, amount)))
        );
        bool verified = MerkleProofLib.verify(merkleProof, merkleRoot, leaf);

        if (!verified) {
            revert ImproperProof();
        }

        uint256 tokensClaimed_ = tokensClaimed[msg.sender][tokenId];
        if (tokensClaimed_ >= amount) {
            revert AlreadyClaimed(amount);
        }

        tokensClaimed[msg.sender][tokenId] = amount;
        //for not overminting
        _mint(msg.sender, tokenId, amount - tokensClaimed_, "");
    }

    /// @dev Set roles to tokenId, can be changed anytime by owner
    function setRoleIds(
        uint256 tokenId_,
        uint256[] calldata roleIds_
    ) external onlyOwner {
        _roleIds[tokenId_] = roleIds_;

        emit SetRoleIds(tokenId_, roleIds_);
    }

    /// @dev Return roles set to tokenId
    function getRoleIds(
        uint256 tokenId
    ) external view returns (uint256[] memory rolesIds_) {
        rolesIds_ = _roleIds[tokenId];
    }

    /// @dev Return tokenURI of choosen tokenId
    function uri(
        uint256 tokenId
    ) public view override returns (string memory tokenURI) {
        tokenURI = LibString.concat(
            NFTicketsFactory(factory).uri(),
            LibString.concat(
                LibString.toHexString(address(this)),
                LibString.concat("/", LibString.toString(tokenId))
            )
        );
    }

    /// @dev Return roleURI of choosen roleId
    function roleURI(
        uint256 roleId
    ) public view returns (string memory roleURI_) {
        roleURI_ = LibString.concat(
            NFTicketsFactory(factory).uri(),
            LibString.concat(
                LibString.toHexString(address(this)),
                LibString.concat("/roles/", LibString.toString(roleId))
            )
        );
    }

    /// @dev get Balances of all tokens that user have
    function getBalances(
        address user
    ) external view returns (uint256[] memory balances) {
        uint256 maxTokenId_ = maxTokenId;
        balances = new uint256[](maxTokenId_);

        for (uint256 i; i != maxTokenId_; ++i) {
            balances[i] = balanceOf[user][i];
        }
    }

    /// @dev Set Start date
    function setStartDate(uint256 startDate_) external onlyOwner {
        startDate = startDate_;

        emit SetStartDate(startDate_);
    }

    /// @dev Set MerkleTreeProof each change in Merkletree
    function setMerkleRoot(bytes32 merkleRoot_) external onlyOwner {
        merkleRoot = merkleRoot_;

        emit SetMerkleRoot(merkleRoot_);
    }

    /// @dev Set MaxTokenId in our event
    function setMaxTokenId(uint256 maxTokenId_) external onlyOwner {
        maxTokenId = maxTokenId_;

        emit SetMaxTokenId(maxTokenId_);
    }

    /// @dev Optional pausing of contract
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
