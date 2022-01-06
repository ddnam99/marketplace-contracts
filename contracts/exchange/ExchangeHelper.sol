// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2;

struct ExchangeItem {
    address nftContractAddress;
    uint256 tokenId;
    address payable seller;
    uint256 price;
    address paymentToken;
    uint256 amount;
    uint256 amountSold;
    bool isCanceled;
    uint256 blockTime;
}

struct SaleHistory {
    address buyer;
    uint256 price;
    uint256 amount;
    uint256 blockTime;
}

library Error {
    string public constant PRICE_MUST_BE_GREATER_THAN_ZERO = "Error: Price must be greater than 0";
    string public constant NFT_IS_NOT_FOR_SALE = "Error: NFT is not for sale";
    string public constant YOU_ARE_NOT_THE_SELLER = "Error: You are not the seller";
    string public constant AMOUNT_MUST_BE_GREATER_THAN_ZERO = "Error: Amount must be greater than 0";
    string public constant EXCHANGE_ITEM_IS_CANCELED = "Error: Exchange item is canceled";
    string public constant AMOUNT_EXCEEDED = "Error: Amount exceeded";
    string public constant CANNOT_BUY_EXCHANGE_ITEM_FROM_YOURSELF = "Error: You can not buy the NFT from yourself";
    string public constant PAYMENT_TOKEN_TRANSFER_TO_SELLER_ERROR = "Error: Payment token transfer to seller error";
    string public constant PAYMENT_TOKEN_TRANSFER_TO_BENEFICIARY_ERROR =
        "Error: Payment token transfer to beneficiary error";
    string public constant PAYMENT_TOKEN_IS_NOT_ALLOWED_BY_BUYER = "Error: Payment token is not allowed by buyer";
}
