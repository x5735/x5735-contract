// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

// For interacting with our own strategy
interface IStrategy {
    // Total want tokens managed by stratfegy
    function wantLockedTotal() external view returns (uint256);

    // Sum of all shares of users to wantLockedTotal
    function sharesTotal() external view returns (uint256);

    // Main want token compounding function
    function earn() external; // if (onlyGov) { gov only }

    function farm() external;

    function pause() external; // gov only

    function unpause() external; // gov only

    // Transfer want tokens Farm -> strategy
    function deposit(
        address _userAddress,
        uint256 _wantAmt
    ) external returns (uint256); // owner only

    // Transfer want tokens strategy -> Farm
    function withdraw(
        address _userAddress,
        uint256 _wantAmt
    ) external returns (uint256); // owner only

    function setEnableAddLiquidity(bool _status) external; // gov only

    function setWITHDRAWALFee(uint256 _WITHDRAWAL_FEE) external; // gov only

    function setControllerFee(uint256 _controllerFee) external; // gov only

    function setbuyBackRate(uint256 _buyBackRate) external; // gov only

    function setReceieveFeeAddress(address _receiveFeeAddress) external; // gov only

    function setGov(address _govAddress) external; // gov only

    function setOnlyGov(bool _onlyGov) external; // gov only

    function setfundManager(address _fundManager) external; // gov only

    function setfundManager2(address _fundManager2) external; // gov only

    function setfundManager3(address _fundManager3) external; // gov only

    function setfundManager4(address _fundManager3) external; // gov only
}