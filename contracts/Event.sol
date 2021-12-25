// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2;

library Event {
    event PaymentTokenWhitelistChanged(address paymentToken, bool allowance);
    event NFTContractAddressWhitelistChanged(address paymentToken, bool isERC1155, bool allowance);

    event MarketFeePercentChanged(uint256 newMarketFeePercent);

    event MarketItemCreated(
        uint256 marketItemIndex,
        address indexed nftContract,
        uint256 indexed tokenId,
        uint256 amount,
        address seller,
        uint256 price,
        address paymentToken
    );
    event MarketItemCancel(uint256 marketItemIndex);
    event MarketItemSale(
        uint256 marketItemIndex,
        address indexed nftContract,
        uint256 indexed tokenId,
        address buyer,
        uint256 price,
        uint256 amount
    );
}
