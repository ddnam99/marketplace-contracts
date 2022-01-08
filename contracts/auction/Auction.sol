// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../core/Factory.sol";
import "./AuctionHelper.sol";

contract Auction is Factory {
    AuctionItem[] private _auctionItems;
    // owner => auctionItemIndex[]
    mapping(address => uint256[]) private _auctionItemIndex;
    // auctionItemIndex => bidHistories
    mapping(uint256 => BidHistory[]) private _bidHistories;
    // auctionItemIndex => bider => lastBidHistoryIndex
    mapping(uint256 => mapping(address => uint256)) private _lastBidHistoryIndex;
    // auctionItemIndex => bider => isBided
    mapping(uint256 => mapping(address => bool)) private _isBided;

    event AuctionItemCreated(
        uint256 auctionItemIndex,
        address indexed nftContract,
        uint256 indexed tokenId,
        uint256 amount,
        address owner,
        uint256 startPrice,
        uint256 bidIncrement,
        address paymentToken,
        uint256 startTime,
        uint256 duration,
        uint256 blockTime
    );
    event AuctionItemCanceled(uint256 auctionItemIndex, uint256 blockTime);
    event AuctionItemPlaceBided(uint256 auctionItemIndex, address bider, uint256 price, uint256 blockTime);

    function createAuctionItem(
        address nftContractAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 startPrice,
        uint256 bidIncrement,
        uint256 startTime,
        uint256 duration,
        address paymentToken
    ) external nonReentrant onlyWhitelistNFTContract(nftContractAddress) onlyWhitelistPaymentToken(paymentToken) {
        amount = _transferAsset(nftContractAddress, _msgSender(), address(this), tokenId, amount);

        AuctionItem memory item = AuctionItem(
            nftContractAddress,
            tokenId,
            payable(_msgSender()),
            startPrice,
            bidIncrement,
            paymentToken,
            amount,
            false,
            startTime,
            duration,
            false
        );
        _auctionItems.push(item);

        uint256 auctionItemIndex = _auctionItems.length - 1;
        _auctionItemIndex[_msgSender()].push(auctionItemIndex);

        emit AuctionItemCreated(
            auctionItemIndex,
            nftContractAddress,
            tokenId,
            amount,
            _msgSender(),
            startPrice,
            bidIncrement,
            paymentToken,
            startTime,
            duration,
            block.timestamp
        );
    }

    function cancelAuctionItem(uint256 auctionItemIndex) external nonReentrant {
        require(_auctionItems.length > auctionItemIndex, AuctionError.AUCTION_NOT_FOUND);

        AuctionItem memory auctionItem = _auctionItems[auctionItemIndex];
        require(auctionItem.startTime < block.timestamp, AuctionError.AUCTION_ITEM_IS_COMPLETED);
        require(!auctionItem.isCanceled, AuctionError.AUCTION_ITEM_IS_CANCELED);

        _transferAsset(
            auctionItem.nftContractAddress,
            address(this),
            auctionItem.owner,
            auctionItem.tokenId,
            auctionItem.amount
        );
        _auctionItems[auctionItemIndex].isCanceled = true;

        emit AuctionItemCanceled(auctionItemIndex, block.timestamp);
    }

    function placeBid(uint256 auctionItemIndex, uint256 price) external nonReentrant {
        require(_auctionItems.length > auctionItemIndex, AuctionError.AUCTION_NOT_FOUND);

        AuctionItem memory auctionItem = _auctionItems[auctionItemIndex];

        require(auctionItem.owner != _msgSender(), AuctionError.CANNOT_BID_AUCTION_ITEM_FROM_YOURSELF);
        require(!auctionItem.isCanceled, AuctionError.AUCTION_ITEM_IS_CANCELED);
        require(auctionItem.startTime >= block.timestamp, AuctionError.IT_IS_NOT_TIME_TO_BID_YET);
        require(auctionItem.startTime + auctionItem.duration < block.timestamp, AuctionError.AUCTION_ITEM_IS_COMPLETED);

        uint256 highestBid = auctionItem.startPrice;
        if (_bidHistories[auctionItemIndex].length > 0) {
            highestBid = _bidHistories[auctionItemIndex][_bidHistories[auctionItemIndex].length - 1].price;
        }

        require(price > highestBid, AuctionError.PRICE_MUST_BE_GREATER_THAN_LAST_PRICE);

        price = Math.min(price, highestBid + auctionItem.bidIncrement);

        uint256 payExtra = price;
        if (_isBided[auctionItemIndex][_msgSender()]) {
            uint256 lastBidHistoryIndex = _lastBidHistoryIndex[auctionItemIndex][_msgSender()];
            payExtra = price - _bidHistories[auctionItemIndex][lastBidHistoryIndex].price;
        }

        require(
            IERC20(auctionItem.paymentToken).allowance(payable(_msgSender()), address(this)) >= payExtra,
            AuctionError.PAYMENT_TOKEN_IS_NOT_ALLOWED
        );

        require(
            IERC20(auctionItem.paymentToken).transferFrom(_msgSender(), address(this), payExtra),
            AuctionError.PAYMENT_TOKEN_TRANSFER_FAILED
        );

        BidHistory memory bidHistory = BidHistory(_msgSender(), price);
        _bidHistories[auctionItemIndex].push(bidHistory);

        uint256 bidHistoryIndex = _bidHistories[auctionItemIndex].length - 1;
        _isBided[auctionItemIndex][_msgSender()] = true;
        _lastBidHistoryIndex[auctionItemIndex][_msgSender()] = bidHistoryIndex;

        emit AuctionItemPlaceBided(auctionItemIndex, _msgSender(), price, block.timestamp);
    }

    function withdraw(uint256 auctionItemIndex) external nonReentrant {
        require(_auctionItems.length > auctionItemIndex, AuctionError.AUCTION_NOT_FOUND);

        AuctionItem memory auctionItem = _auctionItems[auctionItemIndex];

        require(!auctionItem.isCanceled, AuctionError.AUCTION_ITEM_IS_CANCELED);
        require(
            auctionItem.startTime + auctionItem.duration > block.timestamp,
            AuctionError.AUCTION_ITEM_IS_NOT_COMPLETED
        );

        // winner the auction should be allowed ti withdraw the auction item
        if (_lastBidHistoryIndex[auctionItemIndex][_msgSender()] == _bidHistories[auctionItemIndex].length - 1) {
            require(_isBided[auctionItemIndex][_msgSender()], AuctionError.NOTING_TO_WITHDRAW);

            _transferAsset(
                auctionItem.nftContractAddress,
                address(this),
                _msgSender(),
                auctionItem.tokenId,
                auctionItem.amount
            );
            _isBided[auctionItemIndex][_msgSender()] = false;
        }

        // anyone who participated but did not win the auction should be allowed to withdraw the full amount of their funds
        if (_lastBidHistoryIndex[auctionItemIndex][_msgSender()] < _bidHistories[auctionItemIndex].length - 2) {
            require(_isBided[auctionItemIndex][_msgSender()], AuctionError.NOTING_TO_WITHDRAW);

            IERC20(auctionItem.paymentToken).transfer(
                _msgSender(),
                _bidHistories[auctionItemIndex][_lastBidHistoryIndex[auctionItemIndex][_msgSender()]].price
            );
            _isBided[auctionItemIndex][_msgSender()] = false;
        }

        if (auctionItem.owner == _msgSender()) {
            require(!auctionItem.isWithdrawn, AuctionError.NOTING_TO_WITHDRAW);
            uint256 highestBid = _bidHistories[auctionItemIndex][_bidHistories[auctionItemIndex].length - 1].price;

            if (feePercent == 0) {
                require(
                    IERC20(auctionItem.paymentToken).transfer(auctionItem.owner, highestBid),
                    AuctionError.PAYMENT_TOKEN_TRANSFER_TO_OWNER_ERROR
                );
            } else {
                uint256 beneficiaryReceivable = (highestBid * feePercent) / (1 ether);
                uint256 ownerReceivable = highestBid - beneficiaryReceivable;
                require(
                    IERC20(auctionItem.paymentToken).transfer(beneficiary, beneficiaryReceivable),
                    AuctionError.PAYMENT_TOKEN_TRANSFER_TO_BENEFICIARY_ERROR
                );
                require(
                    IERC20(auctionItem.paymentToken).transfer(auctionItem.owner, ownerReceivable),
                    AuctionError.PAYMENT_TOKEN_TRANSFER_TO_OWNER_ERROR
                );
            }

            _auctionItems[auctionItemIndex].isWithdrawn = true;
        }
    }

    function getTotalAuctionItemCount() external view returns (uint256) {
        return _auctionItems.length;
    }

    function _getAuctionItemActiveCount(uint256 fromAuctionItemIndex) private view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = fromAuctionItemIndex; i < _auctionItems.length; i++) {
            if (
                !_auctionItems[i].isCanceled && _auctionItems[i].startTime + _auctionItems[i].duration > block.timestamp
            ) count++;
        }

        return count;
    }

    function getAuctionItemActiveCount() external view returns (uint256) {
        return _getAuctionItemActiveCount(0);
    }

    function getAuctionItemActive(uint256 fromAuctionItemIndex, uint256 limit)
        external
        view
        returns (AuctionItem[] memory)
    {
        uint256 auctionItemActiveCount = _getAuctionItemActiveCount(fromAuctionItemIndex);
        if (limit > auctionItemActiveCount) limit = auctionItemActiveCount;
        AuctionItem[] memory auctionItems = new AuctionItem[](limit);
        uint256 index = 0;
        for (uint256 i = fromAuctionItemIndex; i < _auctionItems.length; i++) {
            if (
                !_auctionItems[i].isCanceled && _auctionItems[i].startTime + _auctionItems[i].duration > block.timestamp
            ) {
                auctionItems[index++] = _auctionItems[i];

                if (index == limit) break;
            }
        }
        return auctionItems;
    }

    function getAuctionItem(uint256 auctionItemIndex) external view returns (AuctionItem memory) {
        return _auctionItems[auctionItemIndex];
    }

    function getAuctionItemBidHistories(uint256 auctionItemIndex) external view returns (BidHistory[] memory) {
        return _bidHistories[auctionItemIndex];
    }

    function getTotalAuctionItemByOwnerCount(address owner) external view returns (uint256) {
        return _auctionItemIndex[owner].length;
    }

    function getAuctionItemIndexByOwner(address owner) external view returns (uint256[] memory) {
        return _auctionItemIndex[owner];
    }

    function getAuctionItemsByOwner(
        address owner,
        uint256 offset,
        uint256 limit
    ) external view returns (AuctionItem[] memory) {
        uint256[] memory auctionItemIndexes = _auctionItemIndex[owner];

        if (offset + limit > auctionItemIndexes.length) limit = auctionItemIndexes.length - offset;
        AuctionItem[] memory auctionItems = new AuctionItem[](limit);

        for (uint256 i = 0; i < limit; i++) {
            auctionItems[i] = _auctionItems[auctionItemIndexes[i + offset]];
        }

        return auctionItems;
    }
}
