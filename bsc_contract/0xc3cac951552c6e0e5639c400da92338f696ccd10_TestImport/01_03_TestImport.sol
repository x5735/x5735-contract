// SPDX-License-Identifier: Unlicensed
pragma solidity >=0.4.22 <0.9.0;
import "./Smart_Binance.sol";
contract Smart_Binance_Base {
    struct Node {
        uint32 id; //16777216
        uint32 ALLleftDirect;
        uint32 ALLrightDirect;
        uint24 leftDirect; //65536
        uint24 rightDirect;
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
    Smart_Binary internal NBJ2;
    
}
contract TestImport is Smart_Binance_Base{

    constructor(){
        NBJ = Smart_Binance(0x5741da6D2937E5896e68B1604E25972a4834C701);
        NBJ2 = Smart_Binary(0x3164B3841D2b603ddB43C909C7f6Efd787058541);
    }

    function Import(address User) public {

         require(NBJ.User_Info(User).UPA != address(0),
         "You were not in Smart Binance");
        require(
            !isUserExists(User),
            "This address is already Import!"
        );
        // require(
        //     isUserBlackListExists(User),
        //     "This Address is BlackList!"
        // );
        _allUsersAddress[_userId] = User;
        _userId++;
        Node memory user = Node({
            id: _userId,
            ALLleftDirect:  uint32(NBJ.User_Info(User).LD),
            ALLrightDirect: uint24(NBJ.User_Info(User).RD),
            leftDirect: uint24(NBJ.User_Info(User).LD),
            rightDirect: uint24(NBJ.User_Info(User).RD),
            childs: uint8(NBJ.User_Info(User).CH),
            leftOrrightUpline: NBJ.User_Info(User).OR == 0 ? false : true,
            UplineAddress: NBJ.User_Info(User).UPA,
            leftDirectAddress: NBJ.User_Info(User).LDA,
            rightDirectAddress: NBJ.User_Info(User).RDA
        });
        _users[User] = user;
    }
    function User_Information(address UserAddress)
        public
        view
        returns (Node memory)
    {
        return _users[UserAddress];
    }
    function isUserExists(address user) private view returns (bool) {
        return (_users[user].id != 0);
    }

    function User_Information_SmartBinance(address User)
        public
        view
        returns (Node memory)
    {
        Node memory user = Node({
            id: _userId,
            ALLleftDirect:  uint32(NBJ.User_Info(User).LD),
            ALLrightDirect: uint24(NBJ.User_Info(User).RD),
            leftDirect: uint24(NBJ.User_Info(User).LD),
            rightDirect: uint24(NBJ.User_Info(User).RD),
            childs: uint8(NBJ.User_Info(User).CH),
            leftOrrightUpline: NBJ.User_Info(User).OR == 0 ? false : true,
            UplineAddress: NBJ.User_Info(User).UPA,
            leftDirectAddress: NBJ.User_Info(User).LDA,
            rightDirectAddress: NBJ.User_Info(User).RDA
        });
        return user;
    }
    function User_Information_SmartBinary(address User)
        public
        view
        returns (Node memory)
    {
        Node memory user = Node({
            id: _userId,
            ALLleftDirect:  uint32(NBJ2.User_Information(User).leftDirect),
            ALLrightDirect: uint32(NBJ2.User_Information(User).rightDirect),
            leftDirect: uint24(NBJ2.User_Information(User).leftDirect),
            rightDirect: uint24(NBJ2.User_Information(User).rightDirect),
            childs: uint8(NBJ2.User_Information(User).childs),
            leftOrrightUpline: NBJ2.User_Information(User).leftOrrightUpline == 0 ? false : true,
            UplineAddress: NBJ2.User_Information(User).UplineAddress,
            leftDirectAddress: NBJ2.User_Information(User).leftDirectAddress,
            rightDirectAddress: NBJ2.User_Information(User).rightDirectAddress
        });
        return user;
    }
}
