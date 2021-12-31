// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

import "./AddressesLib.sol";
import "./Struct.sol";
import "./Error.sol";

contract MarketplaceProxy is
    Initializable,
    AccessControlEnumerable,
    Pausable,
    ReentrancyGuard,
    ERC721Holder,
    ERC1155Holder
{
    using AddressesLib for address[];

    address public beneficiary;

    address[] public whitelistPaymentTokens;
    mapping(address => bool) private _whitelistPaymentTokens;

    address[] public whitelistNFTContractAddresses;
    mapping(address => bool) private _whitelistNFTContractAddresses;
    // whitelist NFT contract address => isERC1155
    mapping(address => bool) private _isERC1155;

    uint256 public marketFeePercent = 0 ether;

    MarketItem[] private _marketItems;
    // seller => marketItemIndex[]
    mapping(address => uint256[]) private _marketItemIndex;
    // marketItemIndex => saleHistories
    mapping(uint256 => SaleHistory[]) private _saleHistories;

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
        address paymentToken,
        uint256 blockTime
    );
    event MarketItemCancel(uint256 marketItemIndex, uint256 blockTime);
    event MarketItemSale(
        uint256 marketItemIndex,
        address buyer,
        uint256 price,
        uint256 amount,
        uint256 marketFeePercent,
        uint256 blockTime
    );

    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), Error.ADMIN_ROLE_REQUIRED);
        _;
    }

    modifier onlyWhitelistPaymentToken(address paymentToken) {
        require(_whitelistPaymentTokens[paymentToken], Error.PAYMENT_NOT_ALLOWED);
        _;
    }

    modifier onlyWhitelistNFTContract(address nftContractAddress) {
        require(_whitelistNFTContractAddresses[nftContractAddress], Error.NFT_CONTRACT_NOT_ALLOWED);
        _;
    }

    function initialize(address multiSigAccount) public initializer {
        renounceRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(DEFAULT_ADMIN_ROLE, multiSigAccount);
        beneficiary = multiSigAccount;
    }

    function setBeneficiary(address newBeneficiary) public onlyAdmin {
        beneficiary = newBeneficiary;
    }

    function setWhitelistPaymentToken(address paymentToken, bool allowance) public onlyAdmin {
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
    ) public onlyAdmin {
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

    function setMarketFeePercent(uint256 newMarketFeePercent) public onlyAdmin {
        marketFeePercent = newMarketFeePercent;
        emit MarketFeePercentChanged(newMarketFeePercent);
    }

    function pauseContract() external onlyAdmin {
        _pause();
    }

    function unpauseContract() external onlyAdmin {
        _unpause();
    }

    function _transferNFT(
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

    function createMarketItem(
        address nftContractAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 price,
        address paymentToken
    )
        external
        nonReentrant
        whenNotPaused
        onlyWhitelistNFTContract(nftContractAddress)
        onlyWhitelistPaymentToken(paymentToken)
    {
        require(price > 0, Error.PRICE_MUST_BE_GREATER_THAN_ZERO);

        amount = _transferNFT(nftContractAddress, _msgSender(), address(this), tokenId, amount);

        MarketItem memory item = MarketItem(
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
        _marketItems.push(item);

        uint256 marketItemIndex = _marketItems.length - 1;
        _marketItemIndex[_msgSender()].push(marketItemIndex);

        emit MarketItemCreated(
            marketItemIndex,
            nftContractAddress,
            tokenId,
            amount,
            _msgSender(),
            price,
            paymentToken,
            block.timestamp
        );
    }

    function cancelMarketItem(uint256 marketItemIndex) external nonReentrant whenNotPaused {
        require(_marketItems.length > marketItemIndex, Error.NFT_IS_NOT_FOR_SALE);

        MarketItem memory marketItem = _marketItems[marketItemIndex];
        require(_msgSender() == marketItem.seller, Error.YOU_ARE_NOT_THE_SELLER);
        require(marketItem.amount > marketItem.amountSold, Error.NFT_IS_NOT_FOR_SALE);
        require(!_marketItems[marketItemIndex].isCanceled, Error.MARKET_ITEM_IS_CANCELED);

        _transferNFT(
            marketItem.nftContractAddress,
            address(this),
            marketItem.seller,
            marketItem.tokenId,
            marketItem.amount
        );

        _marketItems[marketItemIndex].isCanceled = true;

        emit MarketItemCancel(marketItemIndex, block.timestamp);
    }

    function createMarketSale(uint256 marketItemIndex, uint256 amount) external nonReentrant whenNotPaused {
        require(_marketItems.length > marketItemIndex, Error.NFT_IS_NOT_FOR_SALE);
        require(!_marketItems[marketItemIndex].isCanceled, Error.MARKET_ITEM_IS_CANCELED);
        require(
            _marketItems[marketItemIndex].amount - _marketItems[marketItemIndex].amountSold >= amount,
            Error.AMOUNT_EXCEEDED
        );

        MarketItem memory marketItem = _marketItems[marketItemIndex];

        require(_msgSender() != marketItem.seller, Error.CANNOT_BUY_MARKET_ITEM_FROM_YOURSELF);

        uint256 price = (marketItem.price * amount) / marketItem.amount;

        require(
            IERC20(marketItem.paymentToken).allowance(payable(_msgSender()), address(this)) >= price,
            Error.PAYMENT_TOKEN_IS_NOT_ALLOWED_BY_BUYER
        );

        if (marketFeePercent == 0) {
            require(
                IERC20(marketItem.paymentToken).transferFrom(payable(_msgSender()), marketItem.seller, price),
                Error.PAYMENT_TOKEN_TRANSFER_TO_SELLER_ERROR
            );
        } else {
            uint256 beneficiaryReceivable = (price * marketFeePercent) / (1 ether);
            uint256 sellerReceivable = price - beneficiaryReceivable;
            require(
                IERC20(marketItem.paymentToken).transferFrom(
                    payable(_msgSender()),
                    payable(beneficiary),
                    beneficiaryReceivable
                ),
                Error.PAYMENT_TOKEN_TRANSFER_TO_BENEFICIARY_ERROR
            );
            require(
                IERC20(marketItem.paymentToken).transferFrom(
                    payable(_msgSender()),
                    marketItem.seller,
                    sellerReceivable
                ),
                Error.PAYMENT_TOKEN_TRANSFER_TO_SELLER_ERROR
            );
        }

        _transferNFT(marketItem.nftContractAddress, address(this), _msgSender(), marketItem.tokenId, amount);

        _marketItems[marketItemIndex].amountSold += amount;

        SaleHistory memory saleHistory = SaleHistory(_msgSender(), price, amount, block.timestamp);
        _saleHistories[marketItemIndex].push(saleHistory);

        emit MarketItemSale(marketItemIndex, _msgSender(), price, amount, marketFeePercent, block.timestamp);
    }

    function getTotalMarketItemCount() external view returns (uint256) {
        return _marketItems.length;
    }

    function _getMarketItemSellingCount(uint256 fromMarketItemIndex) private view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = fromMarketItemIndex; i < _marketItems.length; i++) {
            if (!_marketItems[i].isCanceled && _marketItems[i].amount > _marketItems[i].amountSold) count++;
        }

        return count;
    }

    function getMarketItemSellingCount() external view returns (uint256) {
        return _getMarketItemSellingCount(0);
    }

    function getMarketItemSelling(uint256 fromMarketItemIndex, uint256 limit)
        external
        view
        returns (MarketItem[] memory)
    {
        uint256 marketItemSellingCount = _getMarketItemSellingCount(fromMarketItemIndex);
        if (limit > marketItemSellingCount) limit = marketItemSellingCount;
        MarketItem[] memory marketItems = new MarketItem[](limit);
        uint256 index = 0;
        for (uint256 i = fromMarketItemIndex; i < _marketItems.length; i++) {
            if (!_marketItems[i].isCanceled && _marketItems[i].amount > _marketItems[i].amountSold) {
                marketItems[index++] = _marketItems[i];

                if (index == limit) break;
            }
        }
        return marketItems;
    }

    function getMarketItem(uint256 marketItemIndex) external view returns (MarketItem memory) {
        return _marketItems[marketItemIndex];
    }

    function getMarketItemSaleHistory(uint256 marketItemIndex) external view returns (SaleHistory[] memory) {
        return _saleHistories[marketItemIndex];
    }

    function getTotalMarketItemBySellerCount(address seller) external view returns (uint256) {
        return _marketItemIndex[seller].length;
    }

    function getMarketItemIndexBySeller(address seller) external view returns (uint256[] memory) {
        return _marketItemIndex[seller];
    }

    function getMarketItemsBySeller(
        address seller,
        uint256 offset,
        uint256 limit
    ) external view returns (MarketItem[] memory) {
        uint256[] memory marketItemIndexes = _marketItemIndex[seller];

        if (offset + limit > marketItemIndexes.length) limit = marketItemIndexes.length - offset;
        MarketItem[] memory marketItems = new MarketItem[](limit);

        for (uint256 i = 0; i < limit; i++) {
            marketItems[i] = _marketItems[marketItemIndexes[i + offset]];
        }

        return marketItems;
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
