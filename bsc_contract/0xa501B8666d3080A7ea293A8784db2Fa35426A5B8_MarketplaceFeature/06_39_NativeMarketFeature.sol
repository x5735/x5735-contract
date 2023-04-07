// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.0 <0.9.0;

import "./interfaces/INativeMarketFeature.sol";
import "../FixinCommon.sol";
import "../storage/LibNativeOrdersStorage.sol";
import "../migrations/LibMigrate.sol";

import "../../op-factory.sol";

contract NativeMarketFeature is INativeMarketFeature, FixinCommon {
    modifier isFactory(address _factory) {
        require(
            LibNativeOrdersStorage.getStorage().AllFactoryBasic[_factory] ==
                true ||
                LibNativeOrdersStorage.getStorage().AllFactoryVip[_factory] ==
                true,
            "Is Not Factory"
        );
        _;
    }

    function checkFactoryBasic(address proxy)
        public
        view
        override
        returns (bool)
    {
        return LibNativeOrdersStorage.getStorage().AllFactoryBasic[proxy];
    }

    function addFactoryBasic(address proxy) public override onlyOwner {
        require(
            LibNativeOrdersStorage.getStorage().AllFactoryBasic[proxy] == false,
            "Invalid proxy address"
        );

        LibNativeOrdersStorage.getStorage().AllFactoryBasic[proxy] = true;
        emit AddFactoryBasic(proxy);
    }

    /**
     * @dev Remove operation from factory list.
     */
    function removeFactoryBasic(address proxy) public override onlyOwner {
        LibNativeOrdersStorage.getStorage().AllFactoryBasic[proxy] = false;

        emit RemoveFactoryBasic(proxy);
    }

    function checkFactoryVip(address proxy)
        public
        view
        override
        returns (bool)
    {
        return LibNativeOrdersStorage.getStorage().AllFactoryVip[proxy];
    }

    /**
     * @dev Allow factory.
     */
    function addFactoryVip(address proxy) public override onlyOwner {
        require(
            LibNativeOrdersStorage.getStorage().AllFactoryVip[proxy] == false,
            "Invalid proxy address"
        );

        LibNativeOrdersStorage.getStorage().AllFactoryVip[proxy] = true;
        emit AddFactoryVip(proxy);
    }

    /**
     * @dev Remove operation from factory list.
     */
    function removeFactoryVip(address proxy) public override onlyOwner {
        LibNativeOrdersStorage.getStorage().AllFactoryVip[proxy] = false;
        emit RemoveFactoryVip(proxy);
    }

    function getFeeMarket() public view override returns (uint256) {
        return LibNativeOrdersStorage.getStorage().feeMarket;
    }

    function setFeeMarket(uint256 percent) public override onlyOwner {
        LibNativeOrdersStorage.getStorage().feeMarket = percent;

        emit NewFeeMarket(percent);
    }

    function getFeeCreator() public view override returns (uint256) {
        return LibNativeOrdersStorage.getStorage().feeCreator;
    }

    function setFeeCreator(uint256 percent) public override onlyOwner {
        LibNativeOrdersStorage.getStorage().feeCreator = percent;
        emit NewFeeCreator(percent);
    }

    function getFeeRef() public view override returns (uint256) {
        return LibNativeOrdersStorage.getStorage().feeRef;
    }

    function setFeeRef(uint256 percent) public override onlyOwner {
        LibNativeOrdersStorage.getStorage().feeRef = percent;
        emit NewFeeRef(percent);
    }

    function getFeeAddress() public view override returns (address) {
        return LibNativeOrdersStorage.getStorage().feeAddress;
    }

    function setFeeAddress(address _feeAddress) public override onlyOwner {
        LibNativeOrdersStorage.getStorage().feeAddress = _feeAddress;
        emit NewFeeAddress(_feeAddress);
    }

    function getRefAddress() public view override returns (address) {
        return address(LibNativeOrdersStorage.getStorage().RefContract);
    }

    function setRefAddress(address _RefAddress) public override onlyOwner {
        LibNativeOrdersStorage.getStorage().RefContract = OPV_REF(_RefAddress);
        emit NewRefAddress(_RefAddress);
    }

    function checkBlackListFee(address user)
        public
        view
        override
        returns (bool)
    {
        return LibNativeOrdersStorage.getStorage().blackListFee[user];
    }

    function setBlackListFee(address[] memory user) public override onlyOwner {
        for (uint256 index = 0; index < user.length; index++) {
            LibNativeOrdersStorage.getStorage().blackListFee[
                user[index]
            ] = true;
        }
        emit AddBlackListFee(user);
    }

    function removeBlackListFee(address[] memory user)
        public
        override
        onlyOwner
    {
        for (uint256 index = 0; index < user.length; index++) {
            LibNativeOrdersStorage.getStorage().blackListFee[
                user[index]
            ] = false;
        }

        emit RemoveBlackListFee(user);
    }

    function getMainTokenAddress() public view override returns (address) {
        return address(LibNativeOrdersStorage.getStorage().MainToken);
    }

    function setMainTokenAddress(address _MainToken) public override onlyOwner {
        LibNativeOrdersStorage.getStorage().MainToken = IERC20(_MainToken);
        emit NewMainTokenAddress(_MainToken);
    }

    function getBuyData(
        uint256 price_,
        address factory_,
        address seller_,
        uint256 tokenId_
    ) public view override returns (uint256[] memory, address[] memory) {
        uint256[] memory saveNumber = new uint256[](4);
        address[] memory saveAddr = new address[](4);
        saveNumber[0] =
            (price_ / 10000) *
            LibNativeOrdersStorage.getStorage().feeRef;
        saveNumber[1] =
            (price_ / 10000) *
            LibNativeOrdersStorage.getStorage().feeMarket;
        saveNumber[2] =
            (price_ / 10000) *
            LibNativeOrdersStorage.getStorage().feeCreator;

        if (
            LibNativeOrdersStorage.getStorage().AllFactoryVip[factory_] == true
        ) {
            if (
                LibNativeOrdersStorage.getStorage().blackListFee[seller_] ==
                true
            ) {
                if (
                    LibNativeOrdersStorage.getStorage().RefContract.getRef(
                        seller_
                    ) !=
                    address(0) &&
                    OPVFactory(factory_).creatorOf(tokenId_) != address(0)
                ) {
                    saveAddr[0] = LibNativeOrdersStorage
                        .getStorage()
                        .RefContract
                        .getRef(seller_);
                    saveAddr[1] = address(0);
                    saveNumber[1] = 0;
                    saveAddr[2] = OPVFactory(factory_).creatorOf(tokenId_);
                } else if (
                    LibNativeOrdersStorage.getStorage().RefContract.getRef(
                        seller_
                    ) !=
                    address(0) &&
                    OPVFactory(factory_).creatorOf(tokenId_) == address(0)
                ) {
                    saveAddr[0] = LibNativeOrdersStorage
                        .getStorage()
                        .RefContract
                        .getRef(seller_);
                    saveAddr[1] = address(0);
                    saveNumber[1] = 0;
                    saveAddr[2] = LibNativeOrdersStorage
                        .getStorage()
                        .feeAddress;
                } else if (
                    LibNativeOrdersStorage.getStorage().RefContract.getRef(
                        seller_
                    ) ==
                    address(0) &&
                    OPVFactory(factory_).creatorOf(tokenId_) != address(0)
                ) {
                    //Have creator
                    //Money to ref
                    // MainToken.transferFrom(msg.sender, feeAddress, feeRefItem);
                    saveAddr[0] = LibNativeOrdersStorage
                        .getStorage()
                        .feeAddress;
                    saveAddr[1] = address(0);
                    saveNumber[1] = 0;
                    saveAddr[2] = OPVFactory(factory_).creatorOf(tokenId_);
                    // Money to fund creator
                }
            } else {
                if (
                    LibNativeOrdersStorage.getStorage().RefContract.getRef(
                        seller_
                    ) !=
                    address(0) &&
                    OPVFactory(factory_).creatorOf(tokenId_) != address(0)
                ) {
                    // Have ref & creator
                    //Money to ref
                    saveAddr[0] = LibNativeOrdersStorage
                        .getStorage()
                        .RefContract
                        .getRef(seller_);
                    saveAddr[1] = LibNativeOrdersStorage
                        .getStorage()
                        .feeAddress;
                    saveAddr[2] = OPVFactory(factory_).creatorOf(tokenId_);
                } else if (
                    LibNativeOrdersStorage.getStorage().RefContract.getRef(
                        seller_
                    ) !=
                    address(0) &&
                    OPVFactory(factory_).creatorOf(tokenId_) == address(0)
                ) {
                    //Have ref
                    //Money to ref
                    saveAddr[0] = LibNativeOrdersStorage
                        .getStorage()
                        .RefContract
                        .getRef(seller_);
                    saveAddr[1] = LibNativeOrdersStorage
                        .getStorage()
                        .feeAddress;
                    saveAddr[2] = LibNativeOrdersStorage
                        .getStorage()
                        .feeAddress;
                } else if (
                    LibNativeOrdersStorage.getStorage().RefContract.getRef(
                        seller_
                    ) ==
                    address(0) &&
                    OPVFactory(factory_).creatorOf(tokenId_) != address(0)
                ) {
                    // Have creator
                    // Money to fund creator
                    saveAddr[0] = LibNativeOrdersStorage
                        .getStorage()
                        .feeAddress;
                    saveAddr[1] = LibNativeOrdersStorage
                        .getStorage()
                        .feeAddress;
                    saveAddr[2] = OPVFactory(factory_).creatorOf(tokenId_);
                }
            }
        } else {
            if (
                LibNativeOrdersStorage.getStorage().blackListFee[seller_] ==
                true
            ) {
                if (
                    LibNativeOrdersStorage.getStorage().RefContract.getRef(
                        seller_
                    ) != address(0)
                ) {
                    //Money to ref
                    saveAddr[0] = LibNativeOrdersStorage
                        .getStorage()
                        .RefContract
                        .getRef(seller_);
                    saveAddr[1] = address(0);
                    saveNumber[1] = 0;
                    saveAddr[2] = LibNativeOrdersStorage
                        .getStorage()
                        .feeAddress;
                } else {
                    // Money to fund creator + ref
                    saveAddr[0] = LibNativeOrdersStorage
                        .getStorage()
                        .feeAddress;
                    saveAddr[1] = address(0);
                    saveNumber[1] = 0;
                    saveAddr[2] = LibNativeOrdersStorage
                        .getStorage()
                        .feeAddress;
                }
            } else {
                if (
                    LibNativeOrdersStorage.getStorage().RefContract.getRef(
                        seller_
                    ) != address(0)
                ) {
                    //Money to ref
                    saveAddr[0] = LibNativeOrdersStorage
                        .getStorage()
                        .RefContract
                        .getRef(seller_);
                    saveAddr[1] = LibNativeOrdersStorage
                        .getStorage()
                        .feeAddress;
                    saveAddr[2] = LibNativeOrdersStorage
                        .getStorage()
                        .feeAddress;
                } else {
                    // Money to fund creator + ref + market
                    saveAddr[0] = LibNativeOrdersStorage
                        .getStorage()
                        .feeAddress;
                    saveAddr[1] = LibNativeOrdersStorage
                        .getStorage()
                        .feeAddress;
                    saveAddr[2] = LibNativeOrdersStorage
                        .getStorage()
                        .feeAddress;
                }
            }
        }

        saveAddr[3] = seller_;
        saveNumber[3] = price_ - saveNumber[0] - saveNumber[1] - saveNumber[2];
        return (saveNumber, saveAddr);
    }

    function migrate() external returns (bytes4 success) {
        _registerFeatureFunction(this.checkFactoryBasic.selector);
        _registerFeatureFunction(this.addFactoryBasic.selector);
        _registerFeatureFunction(this.removeFactoryBasic.selector);
        _registerFeatureFunction(this.checkFactoryVip.selector);
        _registerFeatureFunction(this.addFactoryVip.selector);
        _registerFeatureFunction(this.removeFactoryVip.selector);
        _registerFeatureFunction(this.getFeeMarket.selector);
        _registerFeatureFunction(this.setFeeMarket.selector);
        _registerFeatureFunction(this.getFeeCreator.selector);
        _registerFeatureFunction(this.setFeeCreator.selector);
        _registerFeatureFunction(this.getFeeRef.selector);
        _registerFeatureFunction(this.setFeeRef.selector);
        _registerFeatureFunction(this.getFeeAddress.selector);
        _registerFeatureFunction(this.setFeeAddress.selector);
        _registerFeatureFunction(this.getRefAddress.selector);
        _registerFeatureFunction(this.setRefAddress.selector);
        _registerFeatureFunction(this.checkBlackListFee.selector);
        _registerFeatureFunction(this.setBlackListFee.selector);
        _registerFeatureFunction(this.removeBlackListFee.selector);
        _registerFeatureFunction(this.getMainTokenAddress.selector);
        _registerFeatureFunction(this.setMainTokenAddress.selector);
        _registerFeatureFunction(this.getBuyData.selector);
        return LibMigrate.MIGRATE_SUCCESS;
    }
}