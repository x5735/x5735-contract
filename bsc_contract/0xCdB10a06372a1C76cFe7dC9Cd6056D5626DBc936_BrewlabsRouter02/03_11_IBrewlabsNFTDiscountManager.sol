pragma solidity >=0.5.0;

interface IBrewlabsNFTDiscountManager {
    function getNFTDiscount(address _to) external view returns(uint256);
}