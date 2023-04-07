// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "./IMarketplace.sol";
import "../nft/HREANFT.sol";
import "../oracle/Oracle.sol";
import "../data/StructData.sol";

contract Marketplace is IMarketplace, Ownable, ERC721Holder {
    uint256 private refCounter = 999;
    uint8 public commissionBuyPercent = 3;
    address public nft;
    address public token;
    uint256 public discount = 30;
    address public currency;
    address private oracleContract;
    address public systemWallet;
    address public saleWallet = 0xe3C6c3b651348aC36B138AEeAcFdfCB6962BF906;
    bool private reentrancyGuardForBuying = false;
    bool private reentrancyGuardForSelling = false;

    // for network stats
    mapping(address => uint256) totalActiveMembers;
    mapping(address => uint256) referredNftValue;
    mapping(address => uint256) nftCommissionEarned;
    mapping(address => uint256) nftSaleValue;
    mapping(address => StructData.ChildListData) userChildListData;
    mapping(address => StructData.ChildListData) userF1ListData;

    mapping(uint256 => address) private referralCodeUser;
    mapping(address => uint256) private userReferralCode;
    mapping(address => address) private userRef;
    mapping(uint8 => uint32) private referralCommissions;
    mapping(address => bool) private lockedReferralData;

    uint256 private activeSystemTrading = 1680393600; //need to update
    uint256 private saleStrategyOnlyCurrencyStart = 1680393600; // 2023-04-02 00:00:00
    uint256 private saleStrategyOnlyCurrencyEnd = 1681343999; // 2023-04-12 23:59:59
    uint256 private salePercent = 150;
    bool private allowBuyByCurrency = true; //default allow
    bool private allowBuyByToken = false; //default disable
    bool private typePayCom = true; //false is pay com by token, true is pay com by usdt

    address public stakingContractAddress;
    mapping(address => uint256) totalStakeValue;

    constructor(
        address _nft,
        address _token,
        address _oracle,
        address _systemWallet,
        address _currency
    ) {
        nft = _nft;
        token = _token;
        oracleContract = _oracle;
        systemWallet = _systemWallet;
        currency = _currency;
        initDefaultReferral();
    }

    modifier isSystemActive() {
        require(block.timestamp > activeSystemTrading, "MARKETPLACE: SYSTEM OFFLINE");
        _;
    }

    modifier notExpireForSelling() {
        require(
            block.timestamp <= (activeSystemTrading + 3600 * 24 * 365),
            "MARKETPLACE: EXPIRED TO SELL NFT"
        );
        _;
    }

    modifier validRefCode(uint256 _refCode) {
        require(_refCode >= 999, "MARKETPLACE: REF CODE MUST BE GREATER");
        require(referralCodeUser[_refCode] != address(0), "MARKETPLACE: INVALID REF CODE");
        require(_refCode != userReferralCode[msg.sender], "MARKETPLACE: CANNOT REF TO YOURSELF");
        _;
    }

    modifier isAcceptBuyByCurrency() {
        require(allowBuyByCurrency, "MARKETPLACE: ONLY ACCEPT PAYMENT IN TOKEN");
        _;
    }

    modifier isAcceptBuyByToken() {
        require(allowBuyByToken, "MARKETPLACE: ONLY ACCEPT PAYMENT IN CURRENCY");
        _;
    }

    /**
     * @dev init defaul referral as system wallet
     */
    function initDefaultReferral() internal {
        uint256 systemRefCode = nextReferralCounter();
        userReferralCode[systemWallet] = systemRefCode;
        referralCodeUser[systemRefCode] = systemWallet;
    }

    /**
     * @dev set sale wallet to receive token
     */
    function setSaleWalletAddress(address _saleAddress) public override onlyOwner {
        require(_saleAddress != address(0), "MARKETPLACE: INVALID SALE ADDRESS");
        saleWallet = _saleAddress;
    }

    /**
     * @dev set staking contract address
     */
    function setStakingContractAddress(address _stakingAddress) public override onlyOwner {
        require(_stakingAddress != address(0), "MARKETPLACE: INVALID STAKING ADDRESS");
        stakingContractAddress = _stakingAddress;
    }

    /**
     * @dev set discount percent for selling
     */
    function setDiscountPercent(uint8 _discount) public override onlyOwner {
        require(_discount > 0 && _discount < 100, "MARKETPLACE: INVALID DISCOUNT VALUE");
        discount = _discount;
    }

    /**
     * @dev set commission percent for buy
     */
    function setActiveSystemTrading(uint256 _activeTime) public override onlyOwner {
        require(_activeTime > block.timestamp, "MARKETPLACE: INVALID ACTIVE TIME VALUE");
        activeSystemTrading = _activeTime;
    }

    /**
     * @dev set commission percent for buy
     */
    function setCommissionPercent(uint8 _percent) public override onlyOwner {
        require(_percent > 0 && _percent < 100, "MARKETPLACE: INVALID COMMISSION VALUE");
        commissionBuyPercent = _percent;
    }

    /**
     * @dev set sale StrategyOnlyCurrency time starting
     */
    function setSaleStrategyOnlyCurrencyStart(uint256 _newSaleStart) public override onlyOwner {
        require(_newSaleStart > block.timestamp, "MARKETPLACE: INVALID BEGIN SALE VALUE");
        saleStrategyOnlyCurrencyStart = _newSaleStart;
    }

    /**
     * @dev get discount in sale period
     */
    function setSaleStrategyOnlyCurrencyEnd(uint256 _newSaleEnd) public override onlyOwner {
        require(
            _newSaleEnd > saleStrategyOnlyCurrencyStart,
            "MARKETPLACE: TIME ENDING MUST GREATER THAN TIME BEGINNING"
        );
        saleStrategyOnlyCurrencyEnd = _newSaleEnd;
    }

    /**
     * @dev allow buy NFT by currency
     */
    function allowBuyNftByCurrency(bool _activePayByCurrency) public override onlyOwner {
        allowBuyByCurrency = _activePayByCurrency;
    }

    /**
     * @dev allow buy NFT by token
     */
    function allowBuyNftByToken(bool _activePayByToken) public override onlyOwner {
        allowBuyByToken = _activePayByToken;
    }

    /**
     * @dev set type pay com(token or currency)
     */
    function setTypePayCommission(bool _typePayCommission) public override onlyOwner {
        // false is pay com by token
        // true is pay com by usdt
        typePayCom = _typePayCommission;
    }

    /**
     * @dev set sale percent
     */
    function setSalePercent(uint256 _newSalePercent) public override onlyOwner {
        require(_newSalePercent > 0 && _newSalePercent < 1000, "MARKETPLACE: INVALID SALE PERCENT");
        salePercent = _newSalePercent;
    }

    /**
     * @dev set oracle address
     */
    function setOracleAddress(address _oracleAddress) public override onlyOwner {
        require(_oracleAddress != address(0), "MARKETPLACE: INVALID ORACLE ADDRESS");
        address pairAddress = Oracle(_oracleAddress).pairAddress();
        require(ERC20(token).balanceOf(pairAddress) > 0, "MARKETPLACE: INVALID PAIR ADDRESS");
        require(ERC20(currency).balanceOf(pairAddress) > 0, "MARKETPLACE: INVALID PAIR ADDRESS");
        oracleContract = _oracleAddress;
    }

    /**
     * @dev get discount percent if possible
     */
    function getCurrentSalePercent() internal view returns (uint) {
        uint currentSalePercent = 0;
        if (
            block.timestamp >= saleStrategyOnlyCurrencyStart &&
            block.timestamp < saleStrategyOnlyCurrencyEnd
        ) {
            currentSalePercent = salePercent;
        }
        return currentSalePercent;
    }

    function getActiveMemberForAccount(address _wallet) public view override returns (uint256) {
        return totalActiveMembers[_wallet];
    }

    function getReferredNftValueForAccount(address _wallet) public view override returns (uint256) {
        return referredNftValue[_wallet];
    }

    function getNftCommissionEarnedForAccount(
        address _wallet
    ) public view override returns (uint256) {
        return nftCommissionEarned[_wallet];
    }

    function updateNetworkData(
        address _buyer,
        address _refWallet,
        uint256 _totalValueUsdWithDecimal
    ) internal {
        // Update Referred NFT Value
        uint256 currentNftValueInUsdWithDecimal = referredNftValue[_refWallet];
        referredNftValue[_refWallet] = currentNftValueInUsdWithDecimal + _totalValueUsdWithDecimal;
        // Update NFT Commission Earned
        uint256 currentCommissionEarned = nftCommissionEarned[_refWallet];
        uint256 commissionBuy = getComissionPercentInRule(_refWallet);
        uint256 commissionAmountInUsdWithDecimal = (_totalValueUsdWithDecimal * commissionBuy) /
            100;
        nftCommissionEarned[_refWallet] =
            currentCommissionEarned +
            commissionAmountInUsdWithDecimal;
        // Update NFT Sale Value
        uint256 currentNftSaleValue = nftSaleValue[_buyer];
        nftSaleValue[_buyer] = currentNftSaleValue + _totalValueUsdWithDecimal;
    }

    function checkValidRefCodeAdvance(
        address _user,
        uint256 _refCode
    ) public view override returns (bool) {
        bool isValid = true;
        address currentRefUser = getAccountForReferralCode(_refCode);
        address[] memory refTree = new address[](101);
        refTree[0] = _user;
        uint i = 1;
        while (i < 101 && currentRefUser != systemWallet) {
            for (uint j = 0; j < refTree.length; j++) {
                if (currentRefUser == refTree[j]) {
                    isValid = false;
                    break;
                }
            }
            refTree[i] = currentRefUser;
            currentRefUser = getReferralAccountForAccount(currentRefUser);
            ++i;
        }
        return isValid;
    }

    /**
     * @dev buyByCurrency function
     * @param _nftIds list NFT ID want to buy
     * @param _refCode referral code of ref account
     */
    function buyByCurrency(
        uint256[] memory _nftIds,
        uint256 _refCode
    ) public override validRefCode(_refCode) isAcceptBuyByCurrency {
        require(_nftIds.length > 0, "MARKETPLACE: INVALID LIST NFT ID");
        require(_nftIds.length <= 100, "MARKETPLACE: TOO MANY NFT IN SINGLE BUY");
        // Prevent re-entrancy
        require(!reentrancyGuardForBuying, "MARKETPLACE: REENTRANCY DETECTED");
        // Prevent cheat
        require(checkValidRefCodeAdvance(msg.sender, _refCode), "MARKETPLACE: CHEAT REF DETECTED");
        reentrancyGuardForBuying = true;
        // Start processing
        uint256 totalValueUsd;
        uint index;
        for (index = 0; index < _nftIds.length; index++) {
            uint256 priceNftUsd = HREANFT(nft).getNftPriceUsd(_nftIds[index]);
            require(priceNftUsd > 0, "MARKETPLACE: WRONG NFT ID TO BUY");
            require(
                HREANFT(nft).ownerOf(_nftIds[index]) == address(this),
                "MARKETPLACE: NOT OWNER THIS NFT ID"
            );
            totalValueUsd += priceNftUsd;
        }
        uint256 totalValueUsdWithDecimal = totalValueUsd * (10 ** ERC20(currency).decimals());
        //check sale and update total value
        uint currentSale = getCurrentSalePercent();
        uint256 saleValueUsdWithDecimal = 0;
        if (currentSale > 0) {
            saleValueUsdWithDecimal = (currentSale * totalValueUsdWithDecimal) / 1000;
        }
        require(
            ERC20(currency).balanceOf(msg.sender) >=
                (totalValueUsdWithDecimal - saleValueUsdWithDecimal),
            "MARKETPLACE: NOT ENOUGH BALANCE CURRENCY TO BUY NFTs"
        );
        require(
            ERC20(currency).allowance(msg.sender, address(this)) >=
                (totalValueUsdWithDecimal - saleValueUsdWithDecimal),
            "MARKETPLACE: MUST APPROVE FIRST"
        );
        // Transfer currency from buyer to sale wallet
        require(
            ERC20(currency).transferFrom(
                msg.sender,
                saleWallet,
                (totalValueUsdWithDecimal - saleValueUsdWithDecimal)
            ),
            "MARKETPLACE: FAILED IN TRANSFERING CURRENCY TO MARKETPLACE"
        );
        // Get ref infor
        address payable refAddress = payable(getAccountForReferralCode(_refCode));
        require(refAddress != address(0), "MARKETPLACE: CALLER MUST HAVE A REFERRAL ACCOUNT");
        // Update network data
        updateNetworkData(msg.sender, refAddress, totalValueUsdWithDecimal);
        // Transfer nft from marketplace to buyer
        for (index = 0; index < _nftIds.length; index++) {
            try HREANFT(nft).safeTransferFrom(address(this), msg.sender, _nftIds[index]) {
                emit Buy(address(this), msg.sender, _nftIds[index], refAddress);
            } catch (bytes memory _error) {
                reentrancyGuardForBuying = false;
                emit ErrorLog(_error);
                revert("MARKETPLACE: BUY FAILED");
            }
        }
        // Transfer referral commissions & update data
        payReferralCommissions(msg.sender, refAddress, totalValueUsdWithDecimal, typePayCom);
        // Fixed the ref data of buyer
        if (possibleChangeReferralData(msg.sender)) {
            updateReferralData(msg.sender, _refCode);
        }
        // Rollback for next action
        reentrancyGuardForBuying = false;
    }

    /**
     * @dev buyByToken function
     * @param _nftIds list NFT ID want to buy
     * @param _refCode referral code of ref account
     */
    function buyByToken(
        uint256[] memory _nftIds,
        uint256 _refCode
    ) public override validRefCode(_refCode) isAcceptBuyByToken {
        require(_nftIds.length > 0, "MARKETPLACE: INVALID LIST NFT ID");
        require(_nftIds.length <= 100, "MARKETPLACE: TOO MANY NFT IN SINGLE BUY");
        // Prevent re-entrancy
        require(!reentrancyGuardForBuying, "MARKETPLACE: REENTRANCY DETECTED");
        // Prevent cheat
        require(checkValidRefCodeAdvance(msg.sender, _refCode), "MARKETPLACE: CHEAT REF DETECTED");
        reentrancyGuardForBuying = true;
        // Start processing
        uint256 totalValueUsd;
        uint index;
        for (index = 0; index < _nftIds.length; index++) {
            uint256 priceNftUsd = HREANFT(nft).getNftPriceUsd(_nftIds[index]);
            require(priceNftUsd > 0, "MARKETPLACE: WRONG NFT ID TO BUY");
            require(
                HREANFT(nft).ownerOf(_nftIds[index]) == address(this),
                "MARKETPLACE: NOT OWNER THIS NFT ID"
            );
            totalValueUsd += priceNftUsd;
        }
        uint256 totalValueUsdWithDecimal = totalValueUsd * (10 ** ERC20(currency).decimals());
        uint256 totalValueInTokenWithDecimal = Oracle(oracleContract)
            .convertUsdBalanceDecimalToTokenDecimal(totalValueUsdWithDecimal);
        require(totalValueInTokenWithDecimal > 0, "MARKETPLACE: ORACLE NOT WORKING.");
        //check sale and update total value
        uint currentSale = getCurrentSalePercent();
        uint256 saleValueInTokenWithDecimal = 0;
        if (currentSale > 0) {
            saleValueInTokenWithDecimal = (currentSale * totalValueInTokenWithDecimal) / 1000;
        }
        require(
            ERC20(token).balanceOf(msg.sender) >=
                (totalValueInTokenWithDecimal - saleValueInTokenWithDecimal),
            "MARKETPLACE: NOT ENOUGH BALANCE CURRENCY TO BUY NFTs"
        );
        require(
            ERC20(token).allowance(msg.sender, address(this)) >=
                (totalValueInTokenWithDecimal - saleValueInTokenWithDecimal),
            "MARKETPLACE: MUST APPROVE FIRST"
        );
        // Transfer token from buyer to sale wallet
        require(
            ERC20(token).transferFrom(
                msg.sender,
                saleWallet,
                (totalValueInTokenWithDecimal - saleValueInTokenWithDecimal)
            ),
            "MARKETPLACE: FAILED IN TRANSFERING CURRENCY TO MARKETPLACE"
        );
        // Transfer nft from marketplace to buyer
        // Get ref infor
        address payable refAddress = payable(getAccountForReferralCode(_refCode));
        require(refAddress != address(0), "MARKETPLACE: CALLER MUST HAVE A REFERRAL ACCOUNT");
        // Update network data
        updateNetworkData(msg.sender, refAddress, totalValueUsdWithDecimal);
        // transfer
        for (index = 0; index < _nftIds.length; index++) {
            try HREANFT(nft).safeTransferFrom(address(this), msg.sender, _nftIds[index]) {
                emit Buy(address(this), msg.sender, _nftIds[index], refAddress);
            } catch (bytes memory _error) {
                reentrancyGuardForBuying = false;
                emit ErrorLog(_error);
                revert("MARKETPLACE: BUY FAILED");
            }
        }
        // Transfer referral commissions & update data
        payReferralCommissions(msg.sender, refAddress, totalValueUsdWithDecimal, typePayCom);
        // Fixed the ref data of buyer
        if (possibleChangeReferralData(msg.sender)) {
            updateReferralData(msg.sender, _refCode);
        }
        // Rollback for next action
        reentrancyGuardForBuying = false;
    }

    /**
     * @dev sell function
     * @param _nftIds list NFT ID want to sell
     */
    function sell(uint256[] memory _nftIds) public override notExpireForSelling {
        require(_nftIds.length > 0, "MARKETPLACE: INVALID LIST NFT ID");
        require(_nftIds.length <= 100, "MARKETPLACE: TOO MANY NFT IN SINGLE SELL");
        // Prevent re-entrancy
        require(!reentrancyGuardForSelling, "MARKETPLACE: REENTRANCY DETECTED");
        reentrancyGuardForSelling = true;
        uint256 totalValueUsd;
        for (uint index = 0; index < _nftIds.length; index++) {
            require(
                HREANFT(nft).ownerOf(_nftIds[index]) == msg.sender,
                "MARKETPLACE: ONLY NFT'S OWNER CAN SELL"
            );
            uint256 priceNftUsd = HREANFT(nft).getNftPriceUsd(_nftIds[index]);
            require(priceNftUsd > 0, "MARKETPLACE: WRONG NFT ID TO SELL");
            totalValueUsd += priceNftUsd;
        }
        require(
            HREANFT(nft).isApprovedForAll(msg.sender, address(this)),
            "MARKETPLACE: MUST APPROVE FIRST"
        );
        uint256 totalValueUsdWithDecimal = totalValueUsd * (10 ** ERC20(currency).decimals());
        uint256 totalRefundUsdWithDecimal = (totalValueUsdWithDecimal * (100 - discount)) / 100;
        uint256 totalValueInTokenWithDecimal = Oracle(oracleContract)
            .convertUsdBalanceDecimalToTokenDecimal(totalRefundUsdWithDecimal);
        require(
            ERC20(token).balanceOf(address(this)) >= totalValueInTokenWithDecimal,
            "MARKETPLACE: NOT ENOUGH TOKEN BALANCE TO REFUND"
        );
        // Transfer nft from seller to marketplace
        bytes memory data = abi.encode(msg.sender);
        for (uint index = 0; index < _nftIds.length; index++) {
            try HREANFT(nft).safeTransferFrom(msg.sender, address(this), _nftIds[index], data) {
                emit Sell(msg.sender, address(this), _nftIds[index]);
            } catch (bytes memory _error) {
                reentrancyGuardForSelling = false;
                emit ErrorLog(_error);
                revert("MARKETPLACE: SELL FAILED");
            }
        }
        require(
            ERC20(token).transfer(msg.sender, totalValueInTokenWithDecimal),
            "MARKETPLACE: UNABLE TO TRANSFER COMMISSION PAYMENT TO RECIPIENT"
        );
        // Rollback for next action
        reentrancyGuardForSelling = false;
    }

    /**
     * @dev update referral data function
     * @param _user user wallet address
     * @param _valueInUsdWithDecimal stake value in USD with decimal
     */
    function updateStakeValueData(address _user, uint256 _valueInUsdWithDecimal) public override {
        require(
            msg.sender == stakingContractAddress,
            "MARKETPLACE: INVALID CALLER TO UPDATE STAKE DATA"
        );
        uint256 currentStakeValue = totalStakeValue[_user];
        totalStakeValue[_user] = currentStakeValue + _valueInUsdWithDecimal;
    }

    /**
     * @dev update referral data function
     * @param _user user wallet address
     * @param _refCode referral code of ref account
     */
    function updateReferralData(address _user, uint256 _refCode) public override {
        address refAddress = getAccountForReferralCode(_refCode);
        address refOfRefUser = getReferralAccountForAccountExternal(refAddress);
        require(refOfRefUser != _user, "MARKETPLACE: CONFLICT REF CODE");
        require(_refCode != userReferralCode[_user], "MARKETPLACE: CANNOT REF TO YOURSELF");
        require(_refCode != userReferralCode[msg.sender], "MARKETPLACE: CANNOT REF TO YOURSELF");
        if (possibleChangeReferralData(_user)) {
            userRef[_user] = refAddress;
            generateReferralCode(_user);
            lockedReferralDataForAccount(_user);
            // Update Active Members
            uint256 currentMember = totalActiveMembers[refAddress];
            totalActiveMembers[refAddress] = currentMember + 1;
            updateF1ListForRefAccount(refAddress, _user);
            updateChildListForRefAccountMultiLevels(refAddress, _user);
        }
    }

    /**
     * @dev get NFT sale value
     */
    function getNftSaleValueForAccountInUsdDecimal(
        address _wallet
    ) public view override returns (uint256) {
        return nftSaleValue[_wallet];
    }

    /**
     * @dev update refList for refAccount
     */
    function updateF1ListForRefAccount(address _refAccount, address _newChild) internal {
        userF1ListData[_refAccount].childList.push(_newChild);
        userF1ListData[_refAccount].memberCounter += 1;
    }

    /**
     * @dev update refList for refAccount
     */
    function updateChildListForRefAccount(address _refAccount, address _newChild) internal {
        userChildListData[_refAccount].childList.push(_newChild);
        userChildListData[_refAccount].memberCounter += 1;
    }

    /**
     * @dev update refList for refAccount with 200 levels
     */
    function updateChildListForRefAccountMultiLevels(
        address _refAccount,
        address _newChild
    ) internal {
        address currentRef;
        address nextRef = _refAccount;
        uint8 index = 1;
        while (currentRef != nextRef && nextRef != address(0) && index <= 200) {
            currentRef = nextRef;
            updateChildListForRefAccount(currentRef, _newChild);
            index++;
            nextRef = getReferralAccountForAccountExternal(currentRef);
        }
    }

    /**
     * @dev get childlist of an address
     */
    function getChildListForAccount(address _wallet) internal view returns (address[] memory) {
        return userChildListData[_wallet].childList;
    }

    /**
     * @dev get childlist of an address
     */
    function getF1ListForAccount(address _wallet) public view override returns (address[] memory) {
        return userF1ListData[_wallet].childList;
    }

    /**
     * @dev get Team NFT sale value
     */
    function getTeamNftSaleValueForAccountInUsdDecimal(
        address _wallet
    ) public view override returns (uint256) {
        uint256 countTeamMember = userChildListData[_wallet].memberCounter;
        address currentMember;
        uint256 teamNftValue = 0;
        for (uint i = 0; i < countTeamMember; i++) {
            currentMember = userChildListData[_wallet].childList[i];
            teamNftValue += getNftSaleValueForAccountInUsdDecimal(currentMember);
        }
        return teamNftValue;
    }

    /**
     * @dev generate referral code for an account
     */
    function genReferralCodeForAccount() public override returns (uint256) {
        uint256 refCode = userReferralCode[msg.sender];
        if (refCode == 0) {
            generateReferralCode(msg.sender);
        }
        return userReferralCode[msg.sender];
    }

    /**
     * @dev get referral code for an account
     * @param _user user wallet address
     */
    function getReferralCodeForAccount(address _user) public view override returns (uint256) {
        return userReferralCode[_user];
    }

    /**
     * @dev the function return refferal address for specified address
     */
    function getReferralAccountForAccount(address _user) public view override returns (address) {
        address refWallet = address(0);
        refWallet = userRef[_user];
        if (refWallet == address(0)) {
            refWallet = systemWallet;
        }
        return refWallet;
    }

    /**
     * @dev the function return refferal address for specified address (without system)
     */
    function getReferralAccountForAccountExternal(
        address _user
    ) public view override returns (address) {
        return userRef[_user];
    }

    /**
     * @dev get account for referral code
     * @param _refCode refCode
     */
    function getAccountForReferralCode(uint256 _refCode) public view override returns (address) {
        address refAddress = referralCodeUser[_refCode];
        if (refAddress == address(0)) {
            refAddress = systemWallet;
        }
        return refAddress;
    }

    /**
     * @dev generate a referral code for user (internal function)
     * @param _user user wallet address
     */
    function generateReferralCode(address _user) internal {
        if (userReferralCode[_user] == 0) {
            uint256 refCode = nextReferralCounter();
            userReferralCode[_user] = refCode;
            referralCodeUser[refCode] = _user;
        }
    }

    /**
     * @dev update referral counter (internal function)
     */
    function nextReferralCounter() internal returns (uint256) {
        ++refCounter;
        return refCounter;
    }

    /**
     * @dev get current referral counter
     */
    function currrentReferralCounter() public view returns (uint256) {
        return refCounter;
    }

    /**
     * @dev check possible to change referral data for a user
     * @param _user user wallet address
     */
    function possibleChangeReferralData(address _user) public view override returns (bool) {
        return !lockedReferralData[_user];
    }

    /**
     * @dev only update the referral data 1 time. After set cannot change the data again.
     */
    function lockedReferralDataForAccount(address _user) public override {
        require(
            lockedReferralData[_user] == false,
            "MARKETPLACE: USER'S REFERRAL INFORMATION HAS ALREADY BEEN LOCKED"
        );
        lockedReferralData[_user] = true;
    }

    /**
     * @dev get commission percent in new rule.
     */
    function getComissionPercentInRule(address _user) internal view returns (uint256) {
        uint256 comissionPercent = commissionBuyPercent;
        address[] memory allF1s = getF1ListForAccount(_user);
        if (allF1s.length >= 5) {
            uint countF1Meaning = 0;
            uint256 valueStakeRequire = 1000 * (10 ** ERC20(currency).decimals());
            for (uint i = 0; i < allF1s.length; i++) {
                if (totalStakeValue[allF1s[i]] >= valueStakeRequire) {
                    countF1Meaning++;
                }
            }
            if (countF1Meaning >= 5 && countF1Meaning < 10) {
                comissionPercent = 5;
            } else {
                if (countF1Meaning >= 10) {
                    comissionPercent = 6;
                }
            }
        }
        return comissionPercent;
    }

    /**
     * @dev the function pay commission(default 3%) to referral account
     */
    function payReferralCommissions(
        address _buyer,
        address payable _receiver,
        uint256 _amountUsdDecimal,
        bool _typePayCom
    ) internal {
        uint256 commissionPercent = getComissionPercentInRule(_receiver);
        uint256 commissionAmountInUsdDecimal = (_amountUsdDecimal * commissionPercent) / 100;
        if (_typePayCom) {
            //true is pay com by usdt(currency)
            require(
                ERC20(currency).balanceOf(address(this)) >= commissionAmountInUsdDecimal,
                "MARKETPLACE: CURRENCY BALANCE NOT ENOUGH"
            );
            require(
                ERC20(currency).transfer(_receiver, commissionAmountInUsdDecimal),
                "MARKETPLACE: UNABLE TO TRANSFER COMMISSION PAYMENT TO RECIPIENT"
            );
            emit PayCommission(_buyer, _receiver, commissionAmountInUsdDecimal);
        } else {
            uint256 commissionAmountInTokenDecimal = Oracle(oracleContract)
                .convertUsdBalanceDecimalToTokenDecimal(commissionAmountInUsdDecimal);
            require(
                ERC20(token).balanceOf(address(this)) >= commissionAmountInTokenDecimal,
                "MARKETPLACE: TOKEN BALANCE NOT ENOUGH"
            );
            require(
                ERC20(token).transfer(_receiver, commissionAmountInTokenDecimal),
                "MARKETPLACE: UNABLE TO TRANSFER COMMISSION PAYMENT TO RECIPIENT"
            );
            emit PayCommission(_buyer, _receiver, commissionAmountInTokenDecimal);
        }
    }

    /**
     * @dev the function to update system wallet. Only owner can do this action
     */
    function setSystemWallet(address _newSystemWallet) public override onlyOwner {
        require(
            _newSystemWallet != address(0) && _newSystemWallet != systemWallet,
            "MARKETPLACE: INVALID SYSTEM WALLET"
        );
        systemWallet = _newSystemWallet;
        initDefaultReferral();
    }

    /**
     * @dev get currency address
     */
    function getCurrencyAddress() public view override returns (address) {
        return currency;
    }

    /**
     * @dev set currency address only for owner
     */
    function setCurrencyAddress(address _currency) public override onlyOwner {
        require(_currency != address(0), "MARKETPLACE: CURRENCY MUST NOT BE ADDRESSED TO ZERO");
        require(_currency != currency, "MARKETPLACE: MUST BE DIFFERENT CURRENCY ADDRESS");
        currency = _currency;
    }

    /**
     * @dev deposit amount token to this contract for pay commission task
     */
    function depositToken(uint256 _amount) public override {
        require(_amount > 0, "MARKETPLACE: INVALID AMOUNT");
        require(
            ERC20(token).allowance(msg.sender, address(this)) >= _amount,
            "MARKETPLACE: MUST APPROVE FIRST"
        );
        // Transfer currency from buyer to marketplace
        require(
            ERC20(token).transferFrom(msg.sender, address(this), _amount),
            "MARKETPLACE: CANNOT DEPOSIT"
        );
    }

    /**
     * @dev withdraw some token balance from contract to owner account
     */
    function withdrawTokenEmergency(uint256 _amount) public override onlyOwner {
        require(_amount > 0, "MARKETPLACE: INVALID AMOUNT");
        require(
            ERC20(token).balanceOf(address(this)) >= _amount,
            "MARKETPLACE: TOKEN BALANCE NOT ENOUGH"
        );
        require(ERC20(token).transfer(msg.sender, _amount), "MARKETPLACE: CANNOT WITHDRAW TOKEN");
    }

    /**
     * @dev withdraw some currency balance from contract to owner account
     */
    function withdrawCurrencyEmergency(
        address _currency,
        uint256 _amount
    ) public override onlyOwner {
        require(_amount > 0, "MARKETPLACE: INVALID AMOUNT");
        require(
            ERC20(_currency).balanceOf(address(this)) >= _amount,
            "MARKETPLACE: CURRENCY BALANCE NOT ENOUGH"
        );
        require(
            ERC20(_currency).transfer(msg.sender, _amount),
            "MARKETPLACE: CANNOT WITHDRAW CURRENCY"
        );
    }

    /**
     * @dev transfer a NFT from this contract to an account, only owner
     */
    function tranferNftEmergency(address _receiver, uint256 _nftId) public override onlyOwner {
        require(
            HREANFT(nft).ownerOf(_nftId) == address(this),
            "MARKETPLACE: NOT OWNER OF THIS NFT"
        );
        try HREANFT(nft).safeTransferFrom(address(this), _receiver, _nftId, "") {} catch (
            bytes memory _error
        ) {
            emit ErrorLog(_error);
            revert("MARKETPLACE: NFT TRANSFER FAILED");
        }
    }

    /**
     * @dev transfer a list of NFT from this contract to a list of account, only owner
     */
    function tranferMultiNftsEmergency(
        address[] memory _receivers,
        uint256[] memory _nftIds
    ) public override onlyOwner {
        require(_receivers.length == _nftIds.length, "MARKETPLACE: MUST BE SAME SIZE");
        for (uint index = 0; index < _nftIds.length; index++) {
            tranferNftEmergency(_receivers[index], _nftIds[index]);
        }
    }

    receive() external payable {}
}