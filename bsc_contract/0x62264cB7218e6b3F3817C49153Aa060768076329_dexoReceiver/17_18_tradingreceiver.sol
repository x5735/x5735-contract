// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
pragma abicoder v2;

import "./transfer.sol";
import "./interfaces/storageinterface.sol";
import "./interfaces/stakinginterface.sol";
import "./interfaces/tradinginterface.sol";
import "@layerzerolabs/solidity-examples/contracts/lzApp/NonblockingLzApp.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract dexoReceiver is NonblockingLzApp   {
    using SafeMath for uint256;

    struct dexocmd {
        uint cmd;
        address sender;
        uint orderType;
        uint slippageP;
        dexoStorage.Trade  t;
    }

    event callinfo(
        address  trader,
        dexocmd  info
    );

    Staking public stakingI;
    IDexoPosition public tradingI;
    dexocmd public storeDexoCmd;
    // Params (adjustable)
    uint public positionFee = 35; // milipercent 0.1%
    uint public executorFee = 10000000000000000; // 0.05 bnb
    uint public maxPairIndex = 99999;
    function setPositionFee( uint _fee) onlyOwner external {
        positionFee = _fee;
    }
    function setExecutorFee( uint _fee) onlyOwner external {
        executorFee = _fee;
    }
    function setmaxPairIndex(uint mi) onlyOwner external {
        maxPairIndex = mi;
    }
    constructor(address _staking,address _trading,address _lzEndpoint) NonblockingLzApp(_lzEndpoint) {
        stakingI = Staking(_staking);
        tradingI = IDexoPosition(_trading);
    }
    function setExternal(address _staking,address _trading) external onlyOwner {
        stakingI = Staking(_staking);
        tradingI = IDexoPosition(_trading);
    }
    function openTrade(
        dexoStorage.Trade calldata t,
        uint orderType,
        uint slippageP // for market orders only
        )  external payable {

        address sender = msg.sender;
        uint execute = orderType == 0 ? executorFee:executorFee.mul(2);
        require(orderType == 0 ? msg.value>=executorFee:msg.value>=executorFee.mul(2), "Invalid fee");

        uint fee = t.positionSizeDai.mul(positionFee).div(10000);
        uint depositTotal = fee.add(t.positionSizeDai);
        require(orderType == 0 ? msg.value>=executorFee:msg.value>=executorFee.mul(2), "Invalid fee");
        TransferHelper.safeTransferFrom(stakingI.quoteToken(), msg.sender, address(this), depositTotal);
        TransferHelper.safeApprove(stakingI.quoteToken(), address(stakingI), depositTotal);
        TransferHelper.safeTransfer(stakingI.quoteToken(), address(stakingI), depositTotal);
        TransferHelper.safeTransferETH(address(tradingI), execute);
        tradingI._openTrade(t,orderType,slippageP,sender);

    }
    function updateSl(
        uint pairIndex,
        uint index,
        uint newSl
    )  external {

        address sender = msg.sender;
        tradingI._updateSl(pairIndex,index,newSl,sender);
        
    }

    function updateTp(
        uint pairIndex,
        uint index,
        uint newTp
    )  external {

        address sender = msg.sender;
        tradingI._updateTp(pairIndex,index,newTp,sender);
        
    }
    
    function closeTradeByUser(
        uint pairIndex,
        uint index,
        uint slippageP
    )  external {
        address sender = msg.sender;
        tradingI._closeTradeByUser(pairIndex,index,slippageP,sender);
    }

    function cancelOrder(
        uint pairIndex,
        uint index
    )  external {
        
        address sender = msg.sender;
        tradingI._cancelOrder(pairIndex,index,sender);
    }


    function _nonblockingLzReceive(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, bytes memory _payload) internal override {
        
        (dexocmd memory cmd) = abi.decode(_payload, (dexocmd));

        emit callinfo(cmd.sender,cmd);
        
        if(cmd.t.pairIndex<maxPairIndex){

            if(cmd.cmd==0){
                tradingI._openTrade(
                    cmd.t,
                    cmd.orderType,
                    cmd.slippageP,
                    cmd.sender
                );

            }
            if(cmd.cmd==1){
                tradingI._updateSl(
                    cmd.t.pairIndex,
                    cmd.t.index,
                    cmd.t.sl,
                    cmd.sender
                );
            }
            if(cmd.cmd==2){
                tradingI._updateTp(
                    cmd.t.pairIndex,
                    cmd.t.index,
                    cmd.t.tp,
                    cmd.sender
                );
            }
            if(cmd.cmd==3){
                tradingI._closeTradeByUser(
                    cmd.t.pairIndex,
                    cmd.t.index,
                    cmd.slippageP,
                    cmd.sender
                );
            }
            if(cmd.cmd==4){
                tradingI._cancelOrder(
                    cmd.t.pairIndex,
                    cmd.t.index,
                    cmd.sender
                );
            }        
        }else{
            storeDexoCmd = cmd;
        }
    
    }
 

    function withdraw(address _token, uint256 _amount) external onlyOwner {
        require(ERC20(_token).transfer(msg.sender, _amount), 'transferFrom() failed.');
    }
    function payout () public onlyOwner returns(bool res) {

        address payable to = payable(msg.sender);
        to.transfer(address(this).balance);
        return true;
    }   

    // allow this contract to receive ether
    receive() external payable {}
}