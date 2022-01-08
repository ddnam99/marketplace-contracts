//SPDX-License-Identifier: MIT
pragma solidity >=0.8.2;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

contract TOKEN20 is ERC20Capped, ERC20PresetMinterPauser {
    uint256 public constant MAX_SUPPLY = 100 * 1e6 * 1e18;

    constructor(string memory _name, string memory _symbol)
        ERC20Capped(MAX_SUPPLY)
        ERC20PresetMinterPauser(_name, _symbol)
    {}

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC20, ERC20PresetMinterPauser) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _mint(address account, uint256 amount) internal virtual override(ERC20, ERC20Capped) {
        super._mint(account, amount);
    }
}
