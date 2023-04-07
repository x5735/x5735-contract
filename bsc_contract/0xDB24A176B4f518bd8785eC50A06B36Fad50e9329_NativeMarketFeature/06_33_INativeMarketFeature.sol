// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.0 <0.9.0;

interface INativeMarketFeature {
    event AddFactoryBasic(address factory);

    event RemoveFactoryBasic(address factory);

    event AddFactoryVip(address factory);

    event RemoveFactoryVip(address factory);

    event NewFeeMarket(uint256 percent);

    event NewFeeCreator(uint256 percent);

    event NewFeeRef(uint256 percent);

    event NewFeeAddress(address feeAddress);

    event NewRefAddress(address refAddress);

    event AddBlackListFee(address[] users);

    event RemoveBlackListFee(address[] users);

    event NewMainTokenAddress(address mainToken);

    function checkFactoryBasic(address proxy) external view returns (bool);

    function addFactoryBasic(address proxy) external;

    function removeFactoryBasic(address proxy) external;

    function checkFactoryVip(address proxy) external view returns (bool);

    function addFactoryVip(address proxy) external;

    function removeFactoryVip(address proxy) external;

    function getFeeMarket() external view returns (uint256);

    function setFeeMarket(uint256 percent) external;

    function getFeeCreator() external view returns (uint256);

    function setFeeCreator(uint256 percent) external;

    function getFeeRef() external view returns (uint256);

    function setFeeRef(uint256 percent) external;

    function getFeeAddress() external view returns (address);

    function setFeeAddress(address _feeAddress) external;

    function getRefAddress() external view returns (address);

    function setRefAddress(address _RefAddress) external;

    function checkBlackListFee(address user) external view returns (bool);

    function setBlackListFee(address[] memory user) external;

    function removeBlackListFee(address[] memory user) external;

    function getMainTokenAddress() external view returns (address);

    function setMainTokenAddress(address _MainToken) external;

    function getBuyData(
        uint price_,
        address factory_,
        address seller_,
        uint256 tokenId_
    ) external view returns (uint256[] memory, address[] memory);
}