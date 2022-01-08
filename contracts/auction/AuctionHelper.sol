// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2;

struct AuctionItem {
    address nftContractAddress;
    uint256 tokenId;
    address payable owner;
    uint256 startPrice;
    uint256 bidIncrement;
    address paymentToken;
    uint256 amount;
    bool isCanceled;
    uint256 startTime;
    uint256 duration;
    bool isWithdrawn;
}

struct BidHistory {
    address bider;
    uint256 price;
}

library AuctionError {
    string public constant AUCTION_NOT_FOUND = "Error: Auction not found";
    string public constant AUCTION_ITEM_IS_COMPLETED = "Error: Auction item is completed";
    string public constant AUCTION_ITEM_IS_NOT_COMPLETED = "Error: Auction item is not completed";
    string public constant AUCTION_ITEM_IS_CANCELED = "Error: Auction item is canceled";
    string public constant PRICE_MUST_BE_GREATER_THAN_LAST_PRICE = "Error: Price must be greater than last price";
    string public constant PAYMENT_TOKEN_TRANSFER_FAILED = "Error: Payment token transfer failed";
    string public constant PAYMENT_TOKEN_IS_NOT_ALLOWED = "Error: Payment token is not allowed";
    string public constant IT_IS_NOT_TIME_TO_BID_YET = "Error: It's not time to bid yet";
    string public constant CANNOT_BID_AUCTION_ITEM_FROM_YOURSELF = "Error: Cannot bid auction item from yourself";
    string public constant NOTING_TO_WITHDRAW = "Error: Nothing to withdraw";
    string public constant PAYMENT_TOKEN_TRANSFER_TO_OWNER_ERROR = "Error: Payment token transfer to owner error";
    string public constant PAYMENT_TOKEN_TRANSFER_TO_BENEFICIARY_ERROR =
        "Error: Payment token transfer to beneficiary error";
}
