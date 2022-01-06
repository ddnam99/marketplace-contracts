// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

import "../core/Factory.sol";
import "./ExchangeHelper.sol";

contract ExchangeProxy is Factory, Initializable, ERC721Holder, ERC1155Holder {
    ExchangeItem[] private _exchangeItems;
    // seller => exchangeItemIndex[]
    mapping(address => uint256[]) private _exchangeItemIndex;
    // exchangeItemIndex => saleHistories
    mapping(uint256 => SaleHistory[]) private _saleHistories;

    event ExchangeItemCreated(
        uint256 exchangeItemIndex,
        address indexed nftContract,
        uint256 indexed tokenId,
        uint256 amount,
        address seller,
        uint256 price,
        address paymentToken,
        uint256 blockTime
    );
    event ExchangeItemPriceChanged(uint256 exchangeItemIndex, uint256 newPrice);
    event ExchangeItemCancel(uint256 exchangeItemIndex, uint256 blockTime);
    event ExchangeItemSale(
        uint256 exchangeItemIndex,
        address buyer,
        uint256 price,
        uint256 amount,
        uint256 feePercent,
        uint256 blockTime
    );

    function initialize(address multiSigAccount) public initializer {
        renounceRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(DEFAULT_ADMIN_ROLE, multiSigAccount);
        beneficiary = multiSigAccount;
    }

    function createExchangeItem(
        address nftContractAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 price,
        address paymentToken
    ) external nonReentrant onlyWhitelistNFTContract(nftContractAddress) onlyWhitelistPaymentToken(paymentToken) {
        require(price > 0, Error.PRICE_MUST_BE_GREATER_THAN_ZERO);

        amount = _transferNFT(nftContractAddress, _msgSender(), address(this), tokenId, amount);

        ExchangeItem memory item = ExchangeItem(
            nftContractAddress,
            tokenId,
            payable(_msgSender()),
            price,
            paymentToken,
            amount,
            0,
            false,
            block.timestamp
        );
        _exchangeItems.push(item);

        uint256 exchangeItemIndex = _exchangeItems.length - 1;
        _exchangeItemIndex[_msgSender()].push(exchangeItemIndex);

        emit ExchangeItemCreated(
            exchangeItemIndex,
            nftContractAddress,
            tokenId,
            amount,
            _msgSender(),
            price,
            paymentToken,
            block.timestamp
        );
    }

    function updateExchangeItemPrice(uint256 exchangeItemIndex, uint256 newPrice) external nonReentrant {
        require(_exchangeItems.length > exchangeItemIndex, Error.NFT_IS_NOT_FOR_SALE);

        ExchangeItem memory exchangeItem = _exchangeItems[exchangeItemIndex];
        require(_msgSender() == exchangeItem.seller, Error.YOU_ARE_NOT_THE_SELLER);
        require(exchangeItem.amount > exchangeItem.amountSold, Error.NFT_IS_NOT_FOR_SALE);
        require(!_exchangeItems[exchangeItemIndex].isCanceled, Error.EXCHANGE_ITEM_IS_CANCELED);

        require(newPrice > 0, Error.PRICE_MUST_BE_GREATER_THAN_ZERO);

        _exchangeItems[exchangeItemIndex].price = newPrice;

        emit ExchangeItemPriceChanged(exchangeItemIndex, newPrice);
    }

    function cancelExchangeItem(uint256 exchangeItemIndex) external nonReentrant {
        require(_exchangeItems.length > exchangeItemIndex, Error.NFT_IS_NOT_FOR_SALE);

        ExchangeItem memory exchangeItem = _exchangeItems[exchangeItemIndex];
        require(_msgSender() == exchangeItem.seller, Error.YOU_ARE_NOT_THE_SELLER);
        require(exchangeItem.amount > exchangeItem.amountSold, Error.NFT_IS_NOT_FOR_SALE);
        require(!_exchangeItems[exchangeItemIndex].isCanceled, Error.EXCHANGE_ITEM_IS_CANCELED);

        _transferNFT(
            exchangeItem.nftContractAddress,
            address(this),
            exchangeItem.seller,
            exchangeItem.tokenId,
            exchangeItem.amount
        );

        _exchangeItems[exchangeItemIndex].isCanceled = true;

        emit ExchangeItemCancel(exchangeItemIndex, block.timestamp);
    }

    function createExchangeSale(uint256 exchangeItemIndex, uint256 amount) external nonReentrant {
        require(_exchangeItems.length > exchangeItemIndex, Error.NFT_IS_NOT_FOR_SALE);
        require(!_exchangeItems[exchangeItemIndex].isCanceled, Error.EXCHANGE_ITEM_IS_CANCELED);
        require(
            _exchangeItems[exchangeItemIndex].amount - _exchangeItems[exchangeItemIndex].amountSold >= amount,
            Error.AMOUNT_EXCEEDED
        );

        ExchangeItem memory exchangeItem = _exchangeItems[exchangeItemIndex];

        require(_msgSender() != exchangeItem.seller, Error.CANNOT_BUY_EXCHANGE_ITEM_FROM_YOURSELF);

        uint256 price = (exchangeItem.price * amount) / exchangeItem.amount;

        require(
            IERC20(exchangeItem.paymentToken).allowance(payable(_msgSender()), address(this)) >= price,
            Error.PAYMENT_TOKEN_IS_NOT_ALLOWED_BY_BUYER
        );

        if (feePercent == 0) {
            require(
                IERC20(exchangeItem.paymentToken).transferFrom(payable(_msgSender()), exchangeItem.seller, price),
                Error.PAYMENT_TOKEN_TRANSFER_TO_SELLER_ERROR
            );
        } else {
            uint256 beneficiaryReceivable = (price * feePercent) / (1 ether);
            uint256 sellerReceivable = price - beneficiaryReceivable;
            require(
                IERC20(exchangeItem.paymentToken).transferFrom(
                    payable(_msgSender()),
                    payable(beneficiary),
                    beneficiaryReceivable
                ),
                Error.PAYMENT_TOKEN_TRANSFER_TO_BENEFICIARY_ERROR
            );
            require(
                IERC20(exchangeItem.paymentToken).transferFrom(
                    payable(_msgSender()),
                    exchangeItem.seller,
                    sellerReceivable
                ),
                Error.PAYMENT_TOKEN_TRANSFER_TO_SELLER_ERROR
            );
        }

        _transferNFT(exchangeItem.nftContractAddress, address(this), _msgSender(), exchangeItem.tokenId, amount);

        _exchangeItems[exchangeItemIndex].amountSold += amount;

        SaleHistory memory saleHistory = SaleHistory(_msgSender(), price, amount, block.timestamp);
        _saleHistories[exchangeItemIndex].push(saleHistory);

        emit ExchangeItemSale(exchangeItemIndex, _msgSender(), price, amount, feePercent, block.timestamp);
    }

    function getTotalExchangeItemCount() external view returns (uint256) {
        return _exchangeItems.length;
    }

    function _getExchangeItemSellingCount(uint256 fromExchangeItemIndex) private view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = fromExchangeItemIndex; i < _exchangeItems.length; i++) {
            if (!_exchangeItems[i].isCanceled && _exchangeItems[i].amount > _exchangeItems[i].amountSold) count++;
        }

        return count;
    }

    function getExchangeItemSellingCount() external view returns (uint256) {
        return _getExchangeItemSellingCount(0);
    }

    function getExchangeItemSelling(uint256 fromExchangeItemIndex, uint256 limit)
        external
        view
        returns (ExchangeItem[] memory)
    {
        uint256 exchangeItemSellingCount = _getExchangeItemSellingCount(fromExchangeItemIndex);
        if (limit > exchangeItemSellingCount) limit = exchangeItemSellingCount;
        ExchangeItem[] memory exchangeItems = new ExchangeItem[](limit);
        uint256 index = 0;
        for (uint256 i = fromExchangeItemIndex; i < _exchangeItems.length; i++) {
            if (!_exchangeItems[i].isCanceled && _exchangeItems[i].amount > _exchangeItems[i].amountSold) {
                exchangeItems[index++] = _exchangeItems[i];

                if (index == limit) break;
            }
        }
        return exchangeItems;
    }

    function getExchangeItem(uint256 exchangeItemIndex) external view returns (ExchangeItem memory) {
        return _exchangeItems[exchangeItemIndex];
    }

    function getExchangeItemSaleHistory(uint256 exchangeItemIndex) external view returns (SaleHistory[] memory) {
        return _saleHistories[exchangeItemIndex];
    }

    function getTotalExchangeItemBySellerCount(address seller) external view returns (uint256) {
        return _exchangeItemIndex[seller].length;
    }

    function getExchangeItemIndexBySeller(address seller) external view returns (uint256[] memory) {
        return _exchangeItemIndex[seller];
    }

    function getExchangeItemsBySeller(
        address seller,
        uint256 offset,
        uint256 limit
    ) external view returns (ExchangeItem[] memory) {
        uint256[] memory exchangeItemIndexes = _exchangeItemIndex[seller];

        if (offset + limit > exchangeItemIndexes.length) limit = exchangeItemIndexes.length - offset;
        ExchangeItem[] memory exchangeItems = new ExchangeItem[](limit);

        for (uint256 i = 0; i < limit; i++) {
            exchangeItems[i] = _exchangeItems[exchangeItemIndexes[i + offset]];
        }

        return exchangeItems;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlEnumerable, ERC1155Receiver)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
