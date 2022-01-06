// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2;

import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract NFT1155 is ERC1155Supply, ERC1155Burnable, AccessControlEnumerable {
    using Counters for Counters.Counter;

    string private _name;
    string private _symbol;

    Counters.Counter private _tokenIds;
    mapping(uint256 => string) private _tokenUri;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    modifier onlyMinter() {
        require(hasRole(MINTER_ROLE, _msgSender()), "Error: Minter role required");
        _;
    }

    constructor(string memory name_, string memory symbol_) ERC1155("") {
        _name = name_;
        _symbol = symbol_;
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function mint(
        address to,
        uint256 amount,
        string memory tokenUri,
        bytes memory data
    ) external onlyMinter returns (uint256) {
        _tokenIds.increment();

        uint256 newTokenId = _tokenIds.current();

        _mint(to, newTokenId, amount, data);
        _tokenUri[newTokenId] = tokenUri;

        return newTokenId;
    }

    function uri(uint256 id) public view override returns (string memory) {
        return _tokenUri[id];
    }

    function currentTokenId() external view returns (uint256) {
        return _tokenIds.current();
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override(ERC1155, ERC1155Supply) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155, AccessControlEnumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
