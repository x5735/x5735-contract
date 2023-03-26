// contracts/GLXVestingFactory.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/finance/VestingWallet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GLXVestingFactory is Ownable {
    struct SaleConfig {
        string name;
        uint64 startTime;
        uint64 cliff;
        uint64 duration;
        address tokenAddress;
        address holderToken;
        bool isActive;
        string decription;
    }

    mapping(uint256 => mapping(address => address)) public vestingAddresses;

    SaleConfig[] public sales;

    function createVestingToken(
        address beneficiaryAddress,
        uint256 amount,
        uint256 saleId
    ) external onlyOwner {
        require(
            beneficiaryAddress != address(0),
            "OT: invalid beneficiary address"
        );
        require(saleId < sales.length, "OT: invalid saleId");

        SaleConfig storage saleConfig = sales[saleId];

        require(saleConfig.isActive, "OT: saleId is inactive");

        require(
            vestingAddresses[saleId][beneficiaryAddress] == address(0),
            "OT: exist vesting "
        );
        require(
            IERC20(saleConfig.tokenAddress).allowance(
                saleConfig.holderToken,
                address(this)
            ) >= amount,
            "OT: required approve"
        );
        uint64 startTimestamp = saleConfig.startTime + saleConfig.cliff;
        uint64 durationSeconds = saleConfig.duration;

        VestingWallet vestingAddress = new VestingWallet(
            beneficiaryAddress,
            startTimestamp,
            durationSeconds
        );

        vestingAddresses[saleId][beneficiaryAddress] = address(vestingAddress);

        SafeERC20.safeTransferFrom(
            IERC20(saleConfig.tokenAddress),
            saleConfig.holderToken,
            address(vestingAddress),
            amount
        );
    }

    function deactiveSale(uint saleId) external onlyOwner {
        SaleConfig storage saleConfig = sales[saleId];
        saleConfig.isActive = false;
    }

    function activeSale(uint saleId) external onlyOwner {
        SaleConfig storage saleConfig = sales[saleId];
        saleConfig.isActive = true;
    }

    function addNewSaleConfig(
        string calldata _name,
        uint64 _startTime,
        uint64 _cliff,
        uint64 _duration,
        address _tokenAddress,
        address _holderToken,
        string calldata _decription
    ) external onlyOwner {
        sales.push(
            SaleConfig(
                _name,
                _startTime,
                _cliff,
                _duration,
                _tokenAddress,
                _holderToken,
                true,
                _decription
            )
        );
    }

    function getSaleConfigLength() external view returns (uint256) {
        return sales.length;
    }
}