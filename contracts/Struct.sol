// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2;

struct MarketItem {
    address nftContractAddress;
    uint256 tokenId;
    address payable seller;
    uint256 price;
    address paymentToken;
    uint256 amount;
    uint256 amountSold;
    bool isCanceled;
}
