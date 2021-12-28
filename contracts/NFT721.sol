// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract NFT721 is ERC721Enumerable, ERC721URIStorage, ERC721Burnable, AccessControlEnumerable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    modifier onlyMinter() {
        require(hasRole(MINTER_ROLE, _msgSender()), "Error: Minter role required");
        _;
    }

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function mint(address to, string memory tokenUri) external onlyMinter returns (uint256 id) {
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();

        _mint(to, newTokenId);
        _setTokenURI(newTokenId, tokenUri);

        return newTokenId;
    }

    function mint(
        address to,
        string memory tokenUri,
        uint256 amount
    ) external onlyMinter returns (uint256[] memory ids) {
        ids = new uint256[](amount);

        for (uint256 i = 0; i < amount; i++) {
            _tokenIds.increment();

            uint256 newTokenId = _tokenIds.current();

            _mint(to, newTokenId);
            _setTokenURI(newTokenId, tokenUri);

            ids[i] = newTokenId;
        }
    }

    function tokenIdsOfOwner(address ownerAddress) external view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(ownerAddress);

        if (tokenCount == 0) {
            // Return an empty array
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](tokenCount);
            for (uint256 i = 0; i < tokenCount; i++) {
                result[i] = tokenOfOwnerByIndex(ownerAddress, i);
            }
            return result;
        }
    }

    function currentTokenId() external view returns (uint256) {
        return _tokenIds.current();
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, ERC721Enumerable, AccessControlEnumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
