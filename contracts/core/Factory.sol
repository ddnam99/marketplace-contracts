// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

import "../lib/AddressesLib.sol";

contract Factory is AccessControlEnumerable, ReentrancyGuard {
    using AddressesLib for address[];

    address public beneficiary;

    address[] public whitelistPaymentTokens;
    mapping(address => bool) private _whitelistPaymentTokens;

    address[] public whitelistNFTContractAddresses;
    mapping(address => bool) private _whitelistNFTContractAddresses;
    // whitelist NFT contract address => isERC1155
    mapping(address => bool) private _isERC1155;

    uint256 public feePercent = 0 ether;

    event PaymentTokenWhitelistChanged(address paymentToken, bool allowance);
    event NFTContractAddressWhitelistChanged(address contractAddress, bool isERC1155, bool allowance);

    event FeePercentChanged(uint256 newFeePercent);

    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Error: ADMIN role required");
        _;
    }

    modifier onlyWhitelistPaymentToken(address paymentToken) {
        require(_whitelistPaymentTokens[paymentToken], "Error: Payment token not allowed");
        _;
    }

    modifier onlyWhitelistNFTContract(address nftContractAddress) {
        require(_whitelistNFTContractAddresses[nftContractAddress], "Error: NFT contract not allowed");
        _;
    }

    function setBeneficiary(address newBeneficiary) public onlyAdmin nonReentrant {
        beneficiary = newBeneficiary;
    }

    function setWhitelistPaymentToken(address paymentToken, bool allowance) public onlyAdmin nonReentrant {
        _whitelistPaymentTokens[paymentToken] = allowance;

        if (allowance && !whitelistPaymentTokens.exists(paymentToken)) {
            whitelistPaymentTokens.push(paymentToken);
        }

        if (!allowance && whitelistPaymentTokens.exists(paymentToken)) {
            whitelistPaymentTokens.remove(paymentToken);
        }

        emit PaymentTokenWhitelistChanged(paymentToken, allowance);
    }

    function getWhitelistPaymentToken() external view returns (address[] memory) {
        return whitelistPaymentTokens;
    }

    function setWhitelistNFTContractAddress(
        address nftContractAddress,
        bool isERC1155,
        bool allowance
    ) public onlyAdmin nonReentrant {
        _whitelistNFTContractAddresses[nftContractAddress] = allowance;
        _isERC1155[nftContractAddress] = isERC1155;

        if (allowance && !whitelistNFTContractAddresses.exists(nftContractAddress)) {
            whitelistNFTContractAddresses.push(nftContractAddress);
        }

        if (!allowance && whitelistNFTContractAddresses.exists(nftContractAddress)) {
            whitelistNFTContractAddresses.remove(nftContractAddress);
        }

        emit NFTContractAddressWhitelistChanged(nftContractAddress, isERC1155, allowance);
    }

    function getWhitelistNFTContractAddress() external view returns (address[] memory) {
        return whitelistNFTContractAddresses;
    }

    function setFeePercent(uint256 newFeePercent) public onlyAdmin nonReentrant {
        feePercent = newFeePercent;
        emit FeePercentChanged(newFeePercent);
    }

    function _transferAsset(
        address nftContractAddress,
        address from,
        address to,
        uint256 tokenId,
        uint256 amount
    ) internal returns (uint256) {
        if (_isERC1155[nftContractAddress]) {
            IERC1155(nftContractAddress).safeTransferFrom(from, to, tokenId, amount, "");
            return amount;
        } else {
            IERC721(nftContractAddress).safeTransferFrom(from, to, tokenId);
            return 1;
        }
    }
}
