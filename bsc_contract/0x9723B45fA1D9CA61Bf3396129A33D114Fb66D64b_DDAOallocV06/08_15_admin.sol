// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


contract admin is AccessControl
{

    using SafeERC20 for IERC20;

        // Start: Admin functions
        event adminModify(string txt, address addr);
        address[] Admins;
        modifier onlyAdmin()
        {
                require(IsAdmin(_msgSender()), "Access for Admin only");
                _;
        }
        function IsAdmin(address account) public virtual view returns (bool)
        {
                return hasRole(DEFAULT_ADMIN_ROLE, account);
        }
        function AdminAdd(address account) public virtual onlyAdmin
        {
                require(!IsAdmin(account),'Account already ADMIN');
                grantRole(DEFAULT_ADMIN_ROLE, account);
                emit adminModify('Admin added',account);
                Admins.push(account);
        }
        function AdminDel(address account) public virtual onlyAdmin
        {
                require(IsAdmin(account),'Account not ADMIN');
                require(_msgSender()!=account,'You can`t remove yourself');
                revokeRole(DEFAULT_ADMIN_ROLE, account);
                emit adminModify('Admin deleted',account);
        }
    function AdminList()public view returns(address[] memory)
    {
        return Admins;
    }
    function AdminGetCoin(uint256 amount) public onlyAdmin
    {
	if(amount == 0)
	amount = address(this).balance;
        payable(_msgSender()).transfer(amount);
    }

    function AdminGetToken(address tokenAddress, uint256 amount) public onlyAdmin
    {
        IERC20 ierc20Token = IERC20(tokenAddress);
        if(amount == 0)
        amount = ierc20Token.balanceOf(address(this));
        ierc20Token.safeTransfer(_msgSender(), amount);
    }
    // End: Admin functions

}