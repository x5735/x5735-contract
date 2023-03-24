// SPDX-License-Identifier: Unlicensed
pragma solidity >=0.4.22 <0.9.0;
import "./Smart_Binance.sol";
contract Smart_Binance_Base {
    struct Node {
        uint24 id; //16777216
        uint24 ALLleftDirect;
        uint24 ALLrightDirect;
        uint16 leftDirect; //65536
        uint16 rightDirect;
        uint16 depth;
        // uint8 todayCountPoint; //256
        uint8 childs;
        bool leftOrrightUpline;
        address UplineAddress;
        address leftDirectAddress;
        address rightDirectAddress;
    }

    mapping(address => Node) internal _users;
    mapping(uint24 => address) internal _allUsersAddress;
    uint24 internal _userId;
    Smart_Binance internal NBJ;
    
}
contract TestImport is Smart_Binance_Base{

    constructor(){
        NBJ = Smart_Binance(0x5741da6D2937E5896e68B1604E25972a4834C701);
    }

    function Import(address User) public {

        _allUsersAddress[_userId] = User;
        _userId++;
        _users[_allUsersAddress[_userId]] = Node(
            _userId,
            uint24(NBJ.User_Info(User).LD),
            uint24(NBJ.User_Info(User).RD),
            uint16(NBJ.User_Info(User).LD),
            uint16(NBJ.User_Info(User).RD),
            uint16(NBJ.User_Info(User).DP),
            uint8(NBJ.User_Info(User).CH),
            NBJ.User_Info(User).OR == 0 ? false : true,
            NBJ.User_Info(User).UPA,
            NBJ.User_Info(User).LDA,
            NBJ.User_Info(User).RDA
        );
    }
    function User_Information(address UserAddress)
        public
        view
        returns (Node memory)
    {
        return _users[UserAddress];
    }
}
