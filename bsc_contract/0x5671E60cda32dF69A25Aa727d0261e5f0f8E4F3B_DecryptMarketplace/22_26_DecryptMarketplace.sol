//SPDX-License-Identifier: Unlicense
//   _ 
//  |_) |  _   _ |   _ |_   _. o ._     /\       _ _|_ ._ _. | o  _. 
//  |_) | (_) (_ |< (_ | | (_| | | |   /--\ |_| _>  |_ | (_| | | (_| 

pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';
import "../NFT/IERC2981.sol";
import "../NFT/IRoyaltyDistribution.sol";
import '../NFT/I_NFT.sol';

import './EIP712Upgradeable.sol';

interface UnknownToken {
    function supportsInterface(bytes4 interfaceId) external returns (bool);
}

contract DecryptMarketplace
    is Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    EIP712Upgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    event Sale(
        address buyer,
        address seller,
        address tokenAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 quantity
    );

    event BundleSale(
        address buyer,
        address seller,
        address tokenAddress,
        uint256[] tokenId,
        uint256 amount
    );

    event RoyaltyPaid(
        address tokenAddress,
        address royaltyReceiver,
        uint256 royaltyAmount
    );

    event DistributedRoyaltyPaid(
        address tokenAddress,
        address royaltyReceiver,
        RoyaltyShare[] collaborators,
        uint256 royaltyAmount
    );

    event CancelledOrder(
        address seller,
        address tokenAddress,
        uint256 tokenId,
        ListingType listingType
    );

    event NewRoyaltyLimit(uint256 newRoyaltyLimit);
    event NewMarketplaceFee(uint256 newMarketplaceFee);
    event NewSuperAdminShare(uint256);
    event NewAdminAddress(address);

    enum ListingType {
        BUY_NOW,            // 0
        AUCTION,            // 1
        FLOOR_PRICE_BID,    // 2
        BUNDLE_BUY_NOW,     // 3
        BUNDLE_AUCTION      // 4
    }

    /* An ECDSA signature. */
    struct Sig {
        /* v parameter */
        uint8 v;
        /* r parameter */
        bytes32 r;
        /* s parameter */
        bytes32 s;
    }

    struct Order {
        address user;               //Address of the user, who's making and signing the order
        address tokenAddress;       //Token contract address.
        uint256 tokenId;            //Token contract ID. May be left 0 for bundle order
        uint256 quantity;           //Token quantity. For ERC721 - 1
        ListingType listingType;        //0 - Buy Now, 1 - Auction/Simple offer, 2 - Bid on the floor price, 3 - Bundle Buy now, 4 - Bundle auction
        address paymentToken;       //Payment ERC20 token address if order will be paid in ERC20. address(0) for ETH
        uint256 value;              //Amount to be paid. ERC721 and bundle order - full amount to pay. ERC1155 - amount to pay for 1 token
        uint256 deadline;           //Deadline of the order validity. If auction - buyer will be able to claim NFT after auction has ended
        uint256[] bundleTokens;     //List of token IDs for bundle order. For non-bundle - keep empty
        uint256[] bundleTokensQuantity;    //List of quantities for according IDs for bundle order. For non-bundle - keep empty
        uint256 salt;               //Random number for different order hash
    }

    struct PaymentInfo {
        address owner;
        address buyer;
        address tokenAddress;
        uint256 tokenId;
        uint256 amount;
        address paymentToken;
    }


    bytes32 constant ORDER_TYPEHASH = keccak256(
        "Order(address user,address tokenAddress,uint256 tokenId,uint256 quantity,uint256 listingType,address paymentToken,uint256 value,uint256 deadline,uint256[] bundleTokens,uint256[] bundleTokensQuantity,uint256 salt)"
    );

    uint256 public marketplaceFee; //in basis points (250 = 2.5%)
    uint256 public superAdminShare; //in basis points (6000 = 60%)
    uint256 public royaltyLimit;   //in basis points (9000 = 90%)

    address payable public admin;

    //user => order hash => completed or cancelled
    mapping(address => mapping(bytes32 => bool)) public orderIsCancelledOrCompleted;
    //seller => orderHash => Amount of ERC1155 tokens left to sell
    mapping(address => mapping(bytes32 => uint256)) public amountOf1155TokensLeftToSell;


    /*
     * Constructor
     * Params
     * string calldata name - Marketplace name
     * string calldata version - Marketplace version
     * uint256 _marketplaceFee - Marketplace fee in basis points
     * uint256 _superAdminShare - Super admin share of marketplace fee in basis points
     * address payable _admin - Address of regular admin
     * uint256 _royaltyLimit - Maximum amount of royalties in basis points
     * (9000 = 90% of token price can be royalty)
     */
    function initialize(
        string calldata name,
        string calldata version,
        uint256 _marketplaceFee,
        uint256 _superAdminShare,
        address payable _admin,
        uint256 _royaltyLimit
    ) initializer public {
        __Ownable_init();
        __UUPSUpgradeable_init();
        __EIP712_init(name, version);
        require(_admin != address(0), "Zero address");
        marketplaceFee = _marketplaceFee;
        superAdminShare = _superAdminShare;
        admin = _admin;
        royaltyLimit = _royaltyLimit;
    }


    /*
     * This function is called before proxy upgrade and makes sure it is authorized.
     */
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {}


    /*
     * Returns implementation address
     */
    function implementationAddress() external view returns (address){
        return _getImplementation();
    }


    /*
     * Params
     * uint256 _royaltyLimit - royalty limit in basis points
     *
     * Sets new royalty limit for marketplace.
     * If token asks for higher royalty than royalty limit allows,
     * marketplace will send only allowed amount and distributes it according to shares
     * (if royalty distribution is enabled)
     */
    function setRoyaltyLimit(uint256 _royaltyLimit) external onlyOwner{
        require(_royaltyLimit <= 9500,'Over 95%');
        royaltyLimit = _royaltyLimit;
        emit NewRoyaltyLimit(_royaltyLimit);
    }


    /*
     * Params
     * uint256 _marketplaceFee - Marketplace fee in basis points
     *
     * Sets new marketplace fee.
     * Marketplace fee takes specified share of every payment that goes through marketplace and stores on the contract
     */
    function setMarketplaceFee(uint256 _marketplaceFee) external onlyOwner{
        require(_marketplaceFee <= 9500,'Over 95%');
        marketplaceFee = _marketplaceFee;
        emit NewMarketplaceFee(_marketplaceFee);
    }


    /*
     * Params
     * uint256 _superAdminShare - Super Admin share in basis points
     *
     * Sets super admin share of marketplace fee that he will receive.
     * Example: 6000 = 60%. Super admin will receive 60% of marketplace fee. The rest will go to regular admin
     */
    function setSuperAdminShare(uint256 _superAdminShare) external onlyOwner{
        require(_superAdminShare <= 10000,'Invalid value');
        superAdminShare = _superAdminShare;

        emit NewSuperAdminShare(_superAdminShare);
    }


    /*
     * Params
     * address _admin - Regular Admin address
     *
     * Sets regular admin address. Admin will receive specific share of marketplace income
     */
    function setAdminAddress(address payable _admin) external onlyOwner{
        require(_admin != address(0), "Zero address");
        admin = _admin;

        emit NewAdminAddress(_admin);
    }


    /*
     * Params
     * address tokenAddress - Token address
     * bool forbid - Do you want to forbid?
     *** true - forbid, false - allow
     *
     * Forbids/allows trading specific token contract on other marketplaces
     */
    function restrictTokenToThisMarketplace(address tokenAddress, bool forbid) external onlyOwner{
        CustomToken(tokenAddress).forbidToTradeOnOtherMarketplaces(forbid);
    }


    /*
     * Params
     * uint256 amount - Amount to withdraw
     * address payable receiver - Wallet of the receiver
     *
     * Withdraws collected ETH from marketplace contract to specific wallet address.
     */
    function withdrawETH(uint256 amount, address payable receiver) external onlyOwner{
        require(receiver != address(0));
        require(amount != 0);
        receiver.call{value: amount}("");
    }


    /*
     * Params
     * uint256 amount - Amount to withdraw
     * address payable receiver - Wallet of the receiver
     * address tokenAddress - ERC20 token address
     *
     * Withdraws collected ERC20 from marketplace contract to specific wallet address.
     */
    function withdrawERC20(
        uint256 amount,
        address payable receiver,
        address tokenAddress
    ) external onlyOwner{
        require(receiver != address(0));
        require(amount != 0);
        IERC20Upgradeable(tokenAddress).safeTransfer(receiver, amount);
    }

    /*********************    ORDERS PROCESSING   *********************/

    /*
     * Params
     * Order calldata _sellerOrder - Order info on seller side
     * Sig calldata _sellerSig - Seller signature
     * Order calldata _buyerOrder - Order info on buyer side
     * Sig calldata _buyerSig - Buyer signature
     *
     * Function checks and completes buyout order
     * Order and Signature must be of according format (array with correct element order)
     * Please check Order and Sig struct description for more
     * Function is used for buy now, auction, bundle buy now and bundle auction orders
     * It DOES NOT complete Pre Sale orders. Pre Sale orders are processed in {prePurchase} function
     */
    function completeOrder(
        Order calldata _sellerOrder,
        Sig calldata _sellerSig,
        Order calldata _buyerOrder,
        Sig calldata _buyerSig
    ) public payable nonReentrant {
        //if this is auction/accept offer
        bool isAuction = _sellerOrder.listingType == ListingType.AUCTION
            || _sellerOrder.listingType == ListingType.BUNDLE_AUCTION
            || _buyerOrder.listingType == ListingType.FLOOR_PRICE_BID;

        if(isAuction) {
            require(_sellerOrder.user == msg.sender, 'Offer should be accepted by the seller');
        }else{
            require(_buyerOrder.user == msg.sender, 'Buyer address doesnt match');
        }
        if(isAuction) require(_buyerOrder.paymentToken != address(0), 'Only ERC20 for auction');

        bool isERC721 = checkERCType(_buyerOrder.tokenAddress);
        bool isNotBundleOrder = _sellerOrder.listingType != ListingType.BUNDLE_BUY_NOW
                && _sellerOrder.listingType != ListingType.BUNDLE_AUCTION;
        bool isSimpleERC1155sale = !isERC721 && isNotBundleOrder;


        bytes32 sellerHash = buildHash(_sellerOrder);
        //If this is not Simple Offer accepting - check seller signature.
        if(msg.sender == _buyerOrder.user)
            checkSignature(sellerHash, _sellerOrder.user, _sellerSig);

        //If auction - check buyer signature
        if(isAuction){
            bytes32 buyerHash = buildHash(_buyerOrder);
            checkSignature(buyerHash, _buyerOrder.user, _buyerSig);
        }

        //Initialize ERC1155 counter of tokens left to sell
        if(
            isSimpleERC1155sale
            && orderIsCancelledOrCompleted[_sellerOrder.user][sellerHash] == false
            && amountOf1155TokensLeftToSell[_sellerOrder.user][sellerHash] == 0
        ){
            amountOf1155TokensLeftToSell[_sellerOrder.user][sellerHash] = _sellerOrder.quantity;
        }

        checkOrdersValidity(_sellerOrder, _buyerOrder, isERC721, isNotBundleOrder, isAuction);
        checkOrdersCompatibility(_sellerOrder, _buyerOrder, isERC721, isNotBundleOrder, sellerHash);

        //Counting ERC1155 sold
        if(isSimpleERC1155sale)
        {
            amountOf1155TokensLeftToSell[_sellerOrder.user][sellerHash] -= _buyerOrder.quantity;
        }

        //fix order completion before transferring anything to avoid reentrancy
        if(isSimpleERC1155sale) {  //if all ERC1155 tokens are sold
            if(amountOf1155TokensLeftToSell[_sellerOrder.user][sellerHash] == 0) {
                orderIsCancelledOrCompleted[_sellerOrder.user][sellerHash] = true;
            }
        }else {
            if(_buyerOrder.listingType != ListingType.FLOOR_PRICE_BID) {
                orderIsCancelledOrCompleted[_sellerOrder.user][sellerHash] = true;
            }
        }

        if(msg.sender == _sellerOrder.user) {
            orderIsCancelledOrCompleted[_buyerOrder.user][buildHash(_buyerOrder)] = true;
        }

        //Transfer tokens (non-bundle order)
        if(isNotBundleOrder)
            transferTokens(
                _sellerOrder.tokenAddress,
                _sellerOrder.tokenId,
                _sellerOrder.user,
                _buyerOrder.user,
                _buyerOrder.quantity,
                isERC721
            );

        //Transfer bundle
        if(!isNotBundleOrder) transferBundle(_sellerOrder, _buyerOrder, isERC721);

        PaymentInfo memory payment = PaymentInfo(
            _sellerOrder.user,
            _buyerOrder.user,
            _sellerOrder.tokenAddress,
            _sellerOrder.tokenId,
            _buyerOrder.value,
            _sellerOrder.paymentToken
        );

        transferCoins(
            payment,
            isNotBundleOrder
        );

        if(isNotBundleOrder){
            emit Sale(
                _buyerOrder.user,
                _sellerOrder.user,
                _sellerOrder.tokenAddress,
                _buyerOrder.tokenId,
                _buyerOrder.value,
                _buyerOrder.quantity
            );
        } else {
            emit BundleSale(
                _buyerOrder.user,
                _sellerOrder.user,
                _sellerOrder.tokenAddress,
                _sellerOrder.bundleTokens,
                _buyerOrder.value
            );
        }

    }


    /*
     * Params
     * Order calldata _usersOrder - Users's order info
     *
     * Function cancels specific order, making it impossible to complete
     * Any listing or bid can be cancelled
     * Before cancelling function checks user right to cancel this order
     */
    function cancelOrder(
        Order calldata _usersOrder
    ) external {
        require(_usersOrder.user == msg.sender, 'Wrong order');
        bytes32 usersHash = buildHash(_usersOrder);
         require (!orderIsCancelledOrCompleted[msg.sender][usersHash],'Cancelled or complete');
        orderIsCancelledOrCompleted[msg.sender][usersHash] = true;

        emit CancelledOrder(_usersOrder.user, _usersOrder.tokenAddress, _usersOrder.tokenId, _usersOrder.listingType);
    }


    /*
     * Params
     * address ownerAddress - Address of the token owner
     * address tokenAddress - Address of token contract
     * uint256 tokenId - ID index of token user want to purchase
     * uint256 eventId - ID index of Pre Purchase event user want to participate
     * uint256 quantity - Quantity of tokens of specific ID user wants to purchase
     *
     * Function allows to buy tokens during Pre Sale events.
     * Function runs through some validity checks, but uses external token contract function {getTokenInfo}
     * to determine if user is allowed to purchase at this moment.
     * Contract should check event start, end time, whitelist, and other limitations.
     * After transfer of coins and tokens, function runs countTokensBought function on token contract
     * which allows it to keep track of tokens bought for further limitation calculations
     * If token does not allow transfer, "Not allowed" exception will be thrown
     * This should be avoided buy calling {getTokenInfo} from on Front End
     */
    function prePurchase(
        address ownerAddress,
        address tokenAddress,
        uint256 tokenId,
        uint256 eventId,
        uint256 quantity
    ) external payable nonReentrant {
        require
        (
            UnknownToken(tokenAddress).supportsInterface(type(IPreSale1155).interfaceId) ||
            UnknownToken(tokenAddress).supportsInterface(type(IPreSale721).interfaceId),
            "Pre Sale not supported"
        );
        require(ownerAddress != msg.sender,'Cant buy your token');

        bool isERC721 = checkERCType(tokenAddress);
        bool supportsLazyMint = supportsLazyMint(tokenAddress, isERC721);
        bool shouldLazyMint = supportsLazyMint && ((isERC721  && needsLazyMint721(tokenAddress, ownerAddress, tokenId))
        || (!isERC721 && needsLazyMint1155(tokenAddress, ownerAddress, tokenId, quantity)));

        require(
            IERC721(tokenAddress).isApprovedForAll(ownerAddress,address(this)),
            'Not approved'
        );

        uint256 price;

        if(isERC721){
            require(quantity == 1, 'ERC721 is unique');
            require(
                shouldLazyMint
                || IERC721(tokenAddress).ownerOf(tokenId) == ownerAddress,
                'Not an owner'
            );

            (uint256 tokenPrice, address paymentToken, bool availableForBuyer) = IPreSale721(tokenAddress)
                .getTokenInfo(msg.sender, tokenId, eventId);
            require(availableForBuyer, 'Not allowed');
            price = tokenPrice;

            IPreSale721(tokenAddress).countTokensBought(eventId, msg.sender);

            transferTokens(tokenAddress, tokenId, ownerAddress, msg.sender, quantity, true);

            PaymentInfo memory payment = PaymentInfo(
                ownerAddress,
                msg.sender,
                tokenAddress,
                tokenId,
                tokenPrice,
                paymentToken
            );

            transferCoins(payment, true);

        }else{
            require(quantity >= 1, 'Cant buy 0 quantity');
            require(
                shouldLazyMint
                || IERC1155(tokenAddress)
                .balanceOf(ownerAddress, tokenId)  >= quantity,
                'Not enough tokens'
            );

            (uint256 tokenPrice, address paymentToken, bool availableForBuyer) = IPreSale1155(tokenAddress)
            .getTokenInfo(msg.sender, tokenId, quantity, eventId);
            require(availableForBuyer, 'Not allowed');
            price = tokenPrice;

            IPreSale1155(tokenAddress).countTokensBought(msg.sender, tokenId, quantity, eventId);

            transferTokens(tokenAddress, tokenId, ownerAddress, msg.sender, quantity, false);

            PaymentInfo memory payment = PaymentInfo(
                ownerAddress,
                msg.sender,
                tokenAddress,
                tokenId,
                quantity * tokenPrice,
                paymentToken
            );

            transferCoins(payment, true);
        }

        emit Sale(
            msg.sender,
            ownerAddress,
            tokenAddress,
            tokenId,
            price,
            quantity
        );
    }


    /*
     * Params
     * address tokenAddress - Token contract address
     * uint256 tokenId - Token ID index
     * address from - Sender (owner) address
     * address to - Receiver (buyer) address
     * uint256 quantity - Tokens quantity
     * bool isERC721 - Is transferred token ERC721?
     *
     * Function transfers tokens from seller to buyer
     */
    function transferTokens(
        address tokenAddress,
        uint256 tokenId,
        address from,
        address to,
        uint256 quantity,
        bool isERC721
    ) private {
        bool supportsLazyMint = supportsLazyMint(tokenAddress, isERC721);

        if(isERC721){
            bool shouldLazyMint = supportsLazyMint &&
            needsLazyMint721(
                tokenAddress,
                from,
                tokenId
            );

            if(shouldLazyMint){
                ILazyMint721(tokenAddress).lazyMint(to, tokenId);
            }else{
                IERC721(tokenAddress).safeTransferFrom(from, to, tokenId);
            }
        }else{
            bool shouldLazyMint = supportsLazyMint &&
            needsLazyMint1155(
                tokenAddress,
                from,
                tokenId,
                quantity
            );

            if(shouldLazyMint){
                uint256 amountToTransfer = IERC1155(tokenAddress).balanceOf(from, tokenId);
                uint256 amountToMint = quantity - amountToTransfer;
                ILazyMint1155(tokenAddress).lazyMint(to, tokenId, amountToMint);
                if (amountToTransfer > 0) {
                    IERC1155(tokenAddress).safeTransferFrom(from, to, tokenId, amountToTransfer, '');
                }
            }else{
                IERC1155(tokenAddress).safeTransferFrom(from, to, tokenId, quantity, '');
            }
        }
    }


    /*
     * Params
     * Order calldata _sellerOrder - Sellers order information
     * Order calldata _buyerOrder - Sellers order information
     * bool isERC721 - Is transferred token ERC721?
     *
     * Function transfers token bundle from seller to buyer
     */
    function transferBundle(
        Order calldata _sellerOrder,
        Order calldata _buyerOrder,
        bool isERC721
    ) private {
        address tokenAddress = _buyerOrder.tokenAddress;
        bool supportsLazyMint = supportsLazyMint(_sellerOrder.tokenAddress, isERC721);

        for(uint i=0; i<_sellerOrder.bundleTokens.length; i++){
            require(_sellerOrder.bundleTokens[i] == _buyerOrder.bundleTokens[i], 'Wrong tokenId');
            require(_sellerOrder.bundleTokensQuantity[i] == _buyerOrder.bundleTokensQuantity[i], 'Wrong quantity');
            uint256 bundleTokenId = _sellerOrder.bundleTokens[i];
            uint256 bundleTokenQuantity = _sellerOrder.bundleTokensQuantity[i];

            if(isERC721){
                require(bundleTokenQuantity == 1,'ERC721 is unique');
                if(
                    supportsLazyMint &&
                    needsLazyMint721(
                    _sellerOrder.tokenAddress,
                    _sellerOrder.user,
                    bundleTokenId
                    )
                ){
                    ILazyMint721(_sellerOrder.tokenAddress)
                        .lazyMint(_buyerOrder.user, bundleTokenId);
                } else {
                    IERC721(tokenAddress)
                    .safeTransferFrom(
                        _sellerOrder.user,
                        _buyerOrder.user,
                        bundleTokenId
                    );
                }

            } else {
                if(supportsLazyMint &&
                needsLazyMint1155(
                    _sellerOrder.tokenAddress,
                    _sellerOrder.user,
                    bundleTokenId,
                    bundleTokenQuantity
                )){
                    uint256 amountToTransfer = IERC1155(_sellerOrder.tokenAddress)
                        .balanceOf(_sellerOrder.user, bundleTokenId);
                    uint256 amountToMint = bundleTokenQuantity - amountToTransfer;
                    ILazyMint1155(_sellerOrder.tokenAddress)
                        .lazyMint(_buyerOrder.user, bundleTokenId, amountToMint);
                    if (amountToTransfer > 0) {
                        IERC1155(_sellerOrder.tokenAddress).safeTransferFrom(
                            _sellerOrder.user,
                            _buyerOrder.user,
                            bundleTokenId,
                            amountToTransfer,
                            ''
                        );
                    }
                } else {
                    IERC1155(tokenAddress)
                    .safeTransferFrom(
                        _sellerOrder.user,
                        _buyerOrder.user,
                        bundleTokenId,
                        bundleTokenQuantity,
                        ''
                    );
                }
            }
        }
    }


    /*
     * Params
     * PaymentInfo memory payment - Payment information
     * bool isNotBundleOrder - Is this a bundle order?
     *
     * Function transfers ETH or ERC20 from buyer to according wallets/contracts
     */
    function transferCoins(
        PaymentInfo memory payment,
        bool isNotBundleOrder
    ) private {
        bool ERC20Payment = payment.paymentToken != address(0);
        uint256 transactionAmount = payment.amount;

        /******** Checking for ETH/ERC20 enough balance *******/
        if(ERC20Payment){
            require(IERC20(payment.paymentToken)
                .balanceOf(payment.buyer) >= payment.amount, 'Not enough balance');
            require(IERC20(payment.paymentToken)
                .allowance(payment.buyer, address(this)) >= payment.amount, 'Not enough allowance');
        } else {
            require(msg.value >= payment.amount,'Not enough {value}');
        }

        /**************** TRANSFER ***************/
        /******** Supporting royalty distribution *******/
        if(UnknownToken(payment.tokenAddress).supportsInterface(type(IRoyaltyDistribution).interfaceId)){
            IRoyaltyDistribution tokenContract = IRoyaltyDistribution(payment.tokenAddress);

            if(
                tokenContract.royaltyDistributionEnabled()
                && tokenContract.getDefaultRoyaltyDistribution().length > 0
            ){

                /******** Individual token royalty distribution *******/
                /******** Bundle order doesnt support royalty distribution *******/
                if(
                    isNotBundleOrder
                    && tokenContract.getTokenRoyaltyDistribution(payment.tokenId).length > 0
                ){
                    RoyaltyShare[] memory royaltyShares = tokenContract.getTokenRoyaltyDistribution(payment.tokenId);
                    (address royaltyReceiver, uint256 royaltyAmount) = IRoyaltyDistribution(payment.tokenAddress)
                                                                    .royaltyInfo(payment.tokenId, payment.amount);
                    payDistributedRoyalty
                    (
                        payment,
                        royaltyReceiver,
                        royaltyAmount,
                        royaltyShares
                    );
                /******** Default royalty distribution *******/
                } else {
                    RoyaltyShare[] memory royaltyShares = tokenContract.getDefaultRoyaltyDistribution();
                    (address royaltyReceiver, uint256 royaltyAmount) = IRoyaltyDistribution(payment.tokenAddress)
                                                                    .royaltyInfo(payment.tokenId, payment.amount);
                    payDistributedRoyalty
                    (
                        payment,
                        royaltyReceiver,
                        royaltyAmount,
                        royaltyShares
                    );
                }
            /******** IERC2981 royalty *******/
            } else {
                (address royaltyReceiver, uint256 royaltyAmount) = IRoyaltyDistribution(payment.tokenAddress)
                                                                .royaltyInfo(payment.tokenId, payment.amount);
                payRoyaltyIERC2981
                (
                    payment.buyer,
                    payment.owner,
                    payment.paymentToken,
                    payment.amount,
                    royaltyReceiver,
                    royaltyAmount,
                    payment.tokenAddress
                );
            }

        /******** Supporting IERC2981 *******/
        }else if(UnknownToken(payment.tokenAddress).supportsInterface(type(IERC2981).interfaceId)) {
            (address royaltyReceiver, uint256 royaltyAmount) = IRoyaltyDistribution(payment.tokenAddress)
                                                            .royaltyInfo(payment.tokenId, payment.amount);
            payRoyaltyIERC2981
            (
                payment.buyer,
                payment.owner,
                payment.paymentToken,
                payment.amount,
                royaltyReceiver,
                royaltyAmount,
                payment.tokenAddress
            );

        /******** No royalty *******/
        }else{
            uint256 marketplaceFeeAmount = transactionAmount * marketplaceFee / 10000;
            uint256 amountforSeller = transactionAmount - marketplaceFeeAmount;

            transferMarketingFee(ERC20Payment, payment.paymentToken, marketplaceFeeAmount, payment.buyer);
            if(ERC20Payment) {
                IERC20Upgradeable(payment.paymentToken)
                    .safeTransferFrom(payment.buyer, payment.owner, amountforSeller);
            } else {
                payable(payment.owner).call{value: amountforSeller}("");
            }

        }

        /******** Returning ETH leftovers *******/
        if(payment.paymentToken == address(0)){
            uint256 amountToReturn = msg.value - transactionAmount;
            payable(payment.buyer).call{value: amountToReturn}("");
        }
    }


    /*
     * Params
     * address from - Buyer address
     * address to - Seller address
     * address paymentToken - Payment token address (if ETH, then address(0))
     * uint256 totalAmount - Total value of sale
     * address royaltyReceiver - Royalty receiver address
     * uint256 royaltyAmountToReceive - Royalty receiver address
     * address tokenAddress - NFT token contract address
     *
     * Function Send specific amount of ERC20/ETH to seller, marketplace and royalty receiver
     * Supporting IERC2981 standard
     */
    function payRoyaltyIERC2981(
        address from,
        address to,
        address paymentToken,
        uint256 totalAmount,
        address royaltyReceiver,
        uint256 royaltyAmountToReceive,
        address tokenAddress
    ) private {
        if(totalAmount > 0)
        {
            bool ERC20Payment = paymentToken != address(0);
            uint256 marketplaceFeeAmount = totalAmount * marketplaceFee / 10000;
            uint256 royaltyAmount = royaltyAmountToReceive;
            //If royalty receiver asks too much
            uint256 maxRoyaltyAmount = totalAmount * royaltyLimit / 10000;
            if(royaltyAmount > maxRoyaltyAmount)
                royaltyAmount = maxRoyaltyAmount;

            uint256 amountToSeller = totalAmount - marketplaceFeeAmount - royaltyAmount;

            transferMarketingFee(ERC20Payment, paymentToken, marketplaceFeeAmount, from);
            if(ERC20Payment) {
                if(royaltyAmount > 0)
                    IERC20Upgradeable(paymentToken).safeTransferFrom(from, royaltyReceiver, royaltyAmount);
                if(amountToSeller > 0)
                    IERC20Upgradeable(paymentToken).safeTransferFrom(from, to, amountToSeller);
            } else {
                if(royaltyAmount > 0)
                    payable(royaltyReceiver).call{value:royaltyAmount}("");
                if(amountToSeller > 0)
                    payable(to).call{value: amountToSeller}("");
            }

            if(royaltyAmount > 0)
                emit RoyaltyPaid(tokenAddress, royaltyReceiver, royaltyAmount);
        }
    }


    /*
     * Params
     * Order calldata _sellerOrder - Seller order info
     * Order calldata _buyerOrder - Buyer order info
     * address royaltyReceiver - Royalty receiver address
     * uint256 royaltyAmountToReceive - Royalty amount
     * RoyaltyShare[] memory royaltyShares - Array of royalty shares
     *
     * Function transfers ERC20/ETH to marketplace, seller and royalty receivers
     * Function distributes royalty to collaborators and sends what left to royaltyReceiver
     */
    function payDistributedRoyalty(
        PaymentInfo memory payment,
        address royaltyReceiver,
        uint256 royaltyAmountToReceive,
        RoyaltyShare[] memory royaltyShares
    ) private {
        uint256 totalAmount = payment.amount;
        if(totalAmount > 0)
        {
            bool ERC20Payment = payment.paymentToken != address(0);
            uint256 royaltyAmount = royaltyAmountToReceive;
            //stack too deep
            {
                uint256 marketplaceFeeAmount = totalAmount * marketplaceFee / 10000;
                //If royalty receiver asks too much
                uint256 maxRoyaltyAmount = totalAmount * royaltyLimit / 10000;
                if (royaltyAmount > maxRoyaltyAmount)
                    royaltyAmount = maxRoyaltyAmount;

                uint256 amountToSeller = totalAmount - marketplaceFeeAmount - royaltyAmount;


                //paying to marketplace and seller
                transferMarketingFee(ERC20Payment, payment.paymentToken, marketplaceFeeAmount, payment.buyer);
                if (ERC20Payment) {
                    if (amountToSeller > 0)
                        IERC20Upgradeable(payment.paymentToken)
                        .safeTransferFrom(payment.buyer, payment.owner, amountToSeller);
                } else {
                    if (amountToSeller > 0)
                        payable(payment.owner).call{value : amountToSeller}("");
                }
            }

            //paying to royalty receivers
            if(royaltyAmount > 0) {
                uint256 royaltiesLeftToPay = royaltyAmount;
                for(uint i=0; i<royaltyShares.length; i++){
                    address royaltyShareReceiver = royaltyShares[i].collaborator;
                    uint256 royaltyShare = royaltyAmount * royaltyShares[i].share / 10000;
                    if(royaltyShare > 0 && royaltiesLeftToPay >= royaltyShare){
                        if(ERC20Payment){
                            IERC20Upgradeable(payment.paymentToken)
                            .safeTransferFrom(payment.buyer, royaltyShareReceiver, royaltyShare);
                        } else {
                            payable(royaltyShareReceiver).call{value: royaltyShare}("");
                        }
                        royaltiesLeftToPay -= royaltyShare;
                    }
                }
                //If there is royalty left after distribution
                if(royaltiesLeftToPay > 0) {
                    if(ERC20Payment) {
                        IERC20Upgradeable(payment.paymentToken)
                        .safeTransferFrom(payment.buyer, royaltyReceiver, royaltiesLeftToPay);
                    } else {
                        payable(royaltyReceiver).call{value: royaltiesLeftToPay}("");
                    }
                }
            }

            if(royaltyAmount > 0)
                emit DistributedRoyaltyPaid(payment.tokenAddress, royaltyReceiver, royaltyShares, royaltyAmount);
        }
    }


    /*
     * Params
     * bool ERC20Payment - Is this ERC20 transfer?
     * address paymentToken - Payment token address (if ETH, then address(0))
     * uint256 marketplaceFeeAmount - Amount of fee to transfer
     * address buyer - Buyer address
     *
     * Function transfers specified fee amount to this contract (Super Admin) and regular admin
     */
    function transferMarketingFee(
        bool ERC20Payment,
        address paymentToken,
        uint256 marketplaceFeeAmount,
        address buyer
    ) private {
        uint256 superAdminFeeShare = marketplaceFeeAmount * superAdminShare / 10000;
        uint256 adminFeeShare = marketplaceFeeAmount - superAdminFeeShare;

        if(ERC20Payment){
            if(superAdminFeeShare > 0){
                IERC20Upgradeable(paymentToken)
                .safeTransferFrom(buyer, address(this), superAdminFeeShare);
            }
            if(adminFeeShare > 0){
                IERC20Upgradeable(paymentToken)
                .safeTransferFrom(buyer, admin, adminFeeShare);
            }
        } else {
            admin.call{value: adminFeeShare}("");
        }
    }


    /*********************    CHECKS   *********************/

    /*
     * Params
     * Order calldata _sellerOrder - Seller order info
     * Order calldata _buyerOrder - Buyer order info
     * bool isERC721 - Is NFT token of standard ERC721?
     * bool isNotBundleOrder - Is this a bundle order?
     * bool isAuction - Is this auction order?
     *
     * Function checks if orders are valid
     * Important security check
     */
    function checkOrdersValidity(
        Order calldata _sellerOrder,
        Order calldata _buyerOrder,
        bool isERC721,
        bool isNotBundleOrder,
        bool isAuction
    ) private {
        bool supportsLazyMint = supportsLazyMint(_sellerOrder.tokenAddress, isERC721);

        //Quantity and ownership check
        if(isNotBundleOrder){
            require(_sellerOrder.bundleTokens.length == 0, 'Wrong listingType');
            if(isERC721){
                require(_buyerOrder.quantity == 1 && _sellerOrder.quantity == 1, 'Non-1 quantity');
                require(
                    (supportsLazyMint &&
                    needsLazyMint721(
                        _sellerOrder.tokenAddress,
                        _sellerOrder.user,
                        _sellerOrder.tokenId
                    ))
                    ||
                    IERC721(_sellerOrder.tokenAddress).ownerOf(_sellerOrder.tokenId) == _sellerOrder.user,
                    'Not an owner'
                );
            }else{
                require(_buyerOrder.quantity > 0 && _sellerOrder.quantity > 0, '0 quantity');
                require(
                    (supportsLazyMint &&
                    needsLazyMint1155(
                        _sellerOrder.tokenAddress,
                        _sellerOrder.user,
                        _sellerOrder.tokenId,
                        _buyerOrder.quantity
                    ))
                    ||
                    IERC1155(_sellerOrder.tokenAddress)
                    .balanceOf(_sellerOrder.user, _sellerOrder.tokenId)  >= _buyerOrder.quantity,
                    'Not enough tokens'
                );
            }
        }

        if(!isAuction){
            require(_sellerOrder.deadline >= block.timestamp && _buyerOrder.deadline >= block.timestamp, 'Overdue order');
        } else {
            require(_buyerOrder.deadline >= block.timestamp, 'Overdue offer');
        }
    }


    /*
     * Params
     * Order calldata _sellerOrder - Seller order info
     * Order calldata _buyerOrder - Buyer order info
     * bool isERC721 - Is NFT token of standard ERC721?
     * bool isNotBundleOrder - Is this a bundle order
     * bytes32 sellerHash - Hash info of the seller order
     *
     * Function checks if buyer order and seller order are compatible
     * Hash info of the seller order is used to check amount of ERC1155 tokens that were already sold
     * Important security check
     */
    function checkOrdersCompatibility(
        Order calldata _sellerOrder,
        Order calldata _buyerOrder,
        bool isERC721,
        bool isNotBundleOrder,
        bytes32 sellerHash
    ) private view {
        require(_buyerOrder.user != _sellerOrder.user, 'Buyer == Seller');
        require(_buyerOrder.tokenAddress == _sellerOrder.tokenAddress,
            'Different tokens');
        require(_sellerOrder.tokenId == _buyerOrder.tokenId
            || !isNotBundleOrder
            || _buyerOrder.listingType == ListingType.FLOOR_PRICE_BID, 'TokenIDs dont match');
        if(!isERC721 && isNotBundleOrder){
            require(
                amountOf1155TokensLeftToSell[_sellerOrder.user][sellerHash] >= _buyerOrder.quantity,
                'Cant buy that many'
            );
        }
        require(_sellerOrder.listingType == _buyerOrder.listingType, 'Listing type doesnt match');
        require(_sellerOrder.paymentToken == _buyerOrder.paymentToken, 'Payment token dont match');
        require(
            (isNotBundleOrder &&
            ((_sellerOrder.value <= _buyerOrder.value && isERC721) ||
            ((_sellerOrder.value * _buyerOrder.quantity) <= _buyerOrder.value && !isERC721)))
            ||
            (!isNotBundleOrder &&
            (_sellerOrder.value <= _buyerOrder.value)),
            'Value is too small'
        );
        require(
            _sellerOrder.bundleTokens.length == _buyerOrder.bundleTokens.length
            && _sellerOrder.bundleTokensQuantity.length == _buyerOrder.bundleTokensQuantity.length
            ,'Token lists dont match'
        );
    }


    /*
     * Params
     * bytes32 orderHash - Hashed order info
     * address userAddress - User address that will be compared to signer address
     * Sig calldata _sellerSig - Signature data, that wsa generated by signing hash data
     *
     * Function checks if user with userAddress is the one, who signed hash data
     * Important security check
     */
    function checkSignature(
        bytes32 orderHash,
        address userAddress,
        Sig calldata _sellerSig
    ) private view {
        require (!orderIsCancelledOrCompleted[userAddress][orderHash],'Cancelled or complete');
        address recoveredAddress = recoverAddress(orderHash, _sellerSig);
        require(userAddress == recoveredAddress, 'Bad signature');
    }


    /*
     * Params
     * address tokenAddress - NFT token contract address
     *
     * Function checks if contract is valid NFT of ERC721 or ERC1155 standard
     */
    function checkERCType(address tokenAddress) private returns(bool isERC721){
        bool isERC721 = UnknownToken(tokenAddress).supportsInterface(type(IERC721).interfaceId);

        require(
        isERC721 ||
        UnknownToken(tokenAddress).supportsInterface(type(IERC1155).interfaceId),
        'Unknown Token');

        return isERC721;
    }


    /*
     * Params
     * address tokenAddress - NFT token contract address
     * address ownerAddress - NFT token contract's owner address
     * uint256 tokenId - ID index of token that should be sold
     *
     * Function checks if ERC721 token with specific ID needs to be minted
     * Lazy mint works only for Pre Sale OR with owners order to sell this token
     */
    function needsLazyMint721(
        address tokenAddress,
        address ownerAddress,
        uint256 tokenId
    ) private returns(bool){
        return !ILazyMint721(tokenAddress).exists(tokenId)
        && OwnableUpgradeable(tokenAddress).owner() == ownerAddress;
    }


    /*
     * Params
     * address tokenAddress - NFT token contract address
     * address ownerAddress - NFT token contract's owner address
     * uint256 tokenId - ID index of token that should be sold
     * uint256 quantity - Quantity of tokens to be sold
     *
     * Function checks if ERC1155 tokens with specific ID needs to be minted
     * Lazy mint works only for Pre Sale OR with owners order to sell this token
     */
    function needsLazyMint1155(
        address tokenAddress,
        address ownerAddress,
        uint256 tokenId,
        uint256 quantity
    ) private returns(bool){
        return IERC1155(tokenAddress)
        .balanceOf(ownerAddress, tokenId) < quantity
        && OwnableUpgradeable(tokenAddress).owner() == ownerAddress;
    }


    /*
     * Params
     * address tokenAddress - NFT token contract address
     * bool isERC721 - Is this token ERC721?
     *
     * Function checks if token supports Lazy Minting
     * Returns true if it does
     */
    function supportsLazyMint(
        address tokenAddress,
        bool isERC721
    ) private returns(bool){
        return (isERC721 && UnknownToken(tokenAddress).supportsInterface(type(ILazyMint721).interfaceId))
        || (!isERC721 && UnknownToken(tokenAddress).supportsInterface(type(ILazyMint1155).interfaceId));
    }

    /*********************    HASHING   *********************/

    /*
     * Params
     * Order calldata _order - Order info
     *
     * Function builds hash according to hashing typed data standard V4 (EIP712)
     * May be used on off-chain to build order hash
     */
    function buildHash(Order calldata _order) public view returns (bytes32){
        return _hashTypedDataV4(keccak256(abi.encode(
                ORDER_TYPEHASH,
                _order.user,
                _order.tokenAddress,
                _order.tokenId,
                _order.quantity,
                uint256(_order.listingType),
                _order.paymentToken,
                _order.value,
                _order.deadline,
                keccak256(abi.encodePacked(_order.bundleTokens)),
                keccak256(abi.encodePacked(_order.bundleTokensQuantity)),
                _order.salt
            )));
    }


    /*
     * Params
     * bytes32 hash - Hashed order info
     * Sig calldata _sig - Signature, created from signing this hash
     * signature should have structure [v,r,s]
     *
     * Function recovers signer address (public key)
     * This is security operation that is needed to make sure we are working with trustworthy data
     * May be used on off-chain to verify signature
     */
    function recoverAddress(
        bytes32 hash,
        Sig calldata _sig
    ) public view returns(address) {
        (address recoveredAddress, ) = ECDSAUpgradeable.tryRecover(hash, _sig.v, _sig.r, _sig.s);
        return recoveredAddress;
    }
}