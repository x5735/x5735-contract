// SPDX-License-Identifier: MIT
/* =================================================== DEFI HUNTERS DAO ===========================================================
                                            https://defihuntersdao.club/
-----------------------------------------------------------------------------------------------------------------------------------
                                                                        (NN)  NNN
 NNNNNNNNL     NNNNNNNNL       .NNNN.      .NNNNNNN.          .NNNN.    (NN)  NNN
 NNNNNNNNNN.   NNNNNNNNNN.     JNNNN)     JNNNNNNNNNL         JNNNN)    (NN)  NNN                                  JNN
 NNN    4NNN   NNN    4NNN     NNNNNN    (NNN`   `NNN)        NNNNNN    (NN)  NNN     ____.       ____.  .____.    NNN       ___.
 NNN     NNN)  NNN     NNN)   (NN)4NN)   NNN)     (NNN       (NN)4NN)   (NN)  NNN   JNNNNNNN.   JNNNNN) (NNNNNNL (NNNNNN)  NNNNNNN.
 NNN     4NN)  NNN     4NN)   NNN (NNN   NNN`     `NNN       NNN (NNN   (NN)  NNN  (NNN""4NNN. NNNN"""` `F" `NNN)`NNNNNN) JNNF 4NNL
 NNN     JNN)  NNN     JNN)  (NNF  NNN)  NNN       NNN      (NNF  NNN)  (NN)  NNN  NNN)   4NN)(NNN       .JNNNNN)  NNN   (NNN___NNN
 NNN     NNN)  NNN     NNN)  JNNNNNNNNL  NNN)     (NNN      JNNNNNNNNL  (NN)  NNN  NNN    (NN)(NN)      JNNNNNNN)  NNN   (NNNNNNNNN
 NNN    JNNN   NNN    JNNN  .NNNNNNNNNN  4NNN     NNNF     .NNNNNNNNNN  (NN)  NNN  NNN)   JNN)(NNN     (NNN  (NN)  NNN   (NNN 
 NNN___NNNN`   NNN___NNNN`  (NNF    NNN)  NNNNL_JNNNN      (NNF    NNN) (NN)  NNN  (NNN__JNNN  NNNN___.(NNN__NNN)  NNNL_. NNNN____.
 NNNNNNNNN`    NNNNNNNNN`   NNN`    (NNN   4NNNNNNNF       NNN`    (NNN (NN)  NNN   4NNNNNNN`  `NNNNNN) NNNNNNNN)  (NNNN) `NNNNNNN)
 """"""`       """"""`      """      """     """""         """      """  ""   ""`     """"`      `""""`  `""` ""`   `"""`    """"`
--------------------------------------------------------------------------------------------------------------------------------*/
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./admin.sol";


interface IToken
{
        function approve(address spender,uint256 amount)external;
        function allowance(address owner,address spender)external view returns(uint256);
        function balanceOf(address addr)external view returns(uint256);
        function decimals() external view  returns (uint256);
        function name() external view  returns (string memory);
        function symbol() external view  returns (string memory);
        function totalSupply() external view  returns (uint256);
}

contract DDAOallocV06 is AccessControl, Ownable, admin
{
        using SafeERC20 for IERC20;
        using SafeMath for uint256;

    address public AddrVault;

    event DDAOAllocate(uint256 number,address payer,address addr, uint256 sale,uint256 level,uint256 amount,uint256 amount_human);

    uint256[] public SaleList;
    struct sale_struct
    {
    uint256 id;
    bool exists;
    bool enabled;
    bool test_mode;
    bool hidden;
    string name;
    string url;
    string img;
    //	address vault;
    mapping(uint8 => uint256)amount;
    uint256 cap;
    address[] tokens;
    }
    mapping(uint256 => sale_struct)public Sale;
    uint256 public AllocCount = 0;
    mapping (uint256 => uint256) public AllocSaleCount;
    mapping (uint256 => uint256) public AllocSaleAmount;
    mapping (uint256 => mapping(uint256 => uint256)) public AllocSaleLevelCount;
    mapping (uint256 => mapping(uint256 => uint256)) public AllocSaleLevelAmount;

    uint256 public UpdateTime = block.timestamp;


    struct info
    {
    address addr;
    uint256 decimals;
    string name;
    string symbol;
    uint256 totalSupply;
    }
        constructor()
        {
	_setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

    _setupRole(DEFAULT_ADMIN_ROLE, 0x208b02f98d36983982eA9c0cdC6B3208e0f198A3);
    _setupRole(DEFAULT_ADMIN_ROLE, 0x80C01D52e55e5e870C43652891fb44D1810b28A2);

    AddrVault = 0x208b02f98d36983982eA9c0cdC6B3208e0f198A3;
    }

    function TokenAllowance(address TokenAddr,address addr)public view returns(uint256 value)
    {
    value = IToken(TokenAddr).allowance(addr,address(this));
    }
    function TokenInfo(address TokenAddr)public view returns(info memory val)
    {
    val.addr = TokenAddr;
    val.decimals = IToken(TokenAddr).decimals();
    val.name = IToken(TokenAddr).name();
    val.symbol = IToken(TokenAddr).symbol();
    val.totalSupply = IToken(TokenAddr).totalSupply();
    }
    function SaleModify(uint256 id,string memory name,string memory url,string memory img,bool enabled,uint256 amount1,uint256 amount2,uint256 amount3,uint256 cap,uint256 test_mode,uint256 hidden,address[] memory tokens)public onlyAdmin returns(uint256)
    {
            //SaleNum++;
                //require(!Sale[SaleNum].exists,"Sale with this ID exists");
                //require(Sale[SaleNum].id == id,"Sale ID must be SaleNum");
    //uint256 i = SaleNum;
    Sale[id].id = id;
    Sale[id].name 	= name;
    Sale[id].url 	= url;
    Sale[id].img 	= img;
    Sale[id].test_mode = test_mode==1?true:false;
    if(!Sale[id].exists)
    {
    Sale[id].exists = true;
    SaleList.push(id);
    }
    Sale[id].enabled   = enabled;
    Sale[id].hidden    = hidden==1?true:false;
    Sale[id].amount[1] = amount1;
    Sale[id].amount[2] = amount2;
    Sale[id].amount[3] = amount3;
    Sale[id].cap = cap;
    Sale[id].tokens = tokens;
    UpdateTime = block.timestamp;

    return id;
    }
    function SaleModifyTokens(uint256 id,address[] memory tokens)public onlyAdmin
    {
    require(Sale[id].exists,"Sale with this ID not exists");
    Sale[id].tokens = tokens;
    UpdateTime = block.timestamp;
    }
    function SaleModifyTestMode(uint256 id,bool true_or_false)public onlyAdmin
    {
    require(Sale[id].exists,"Sale with this ID not exists");
    Sale[id].test_mode = true_or_false;
    UpdateTime = block.timestamp;
    }
    function SaleModifyHidden(uint256 id,bool true_or_false)public onlyAdmin
    {
    require(Sale[id].exists,"Sale with this ID not exists");
    Sale[id].hidden = true_or_false;
    UpdateTime = block.timestamp;
    }
    function SaleModifyName(uint256 id,string memory name)public onlyAdmin
    {
    require(Sale[id].exists,"Sale with this ID not exists");
    Sale[id].name = name;
    UpdateTime = block.timestamp;
    }
    function SaleModifyUrl(uint256 id,string memory url)public onlyAdmin
    {
    require(Sale[id].exists,"Sale with this ID not exists");
    Sale[id].url = url;
    UpdateTime = block.timestamp;
    }
    function SaleModifyImg(uint256 id,string memory img)public onlyAdmin
    {
    require(Sale[id].exists,"Sale with this ID not exists");
    Sale[id].img = img;
    UpdateTime = block.timestamp;
    }
    function SaleModifyCap(uint256 id,uint256 cap)public onlyAdmin
    {
    require(Sale[id].exists,"Sale with this ID not exists");
    Sale[id].cap = cap;
    UpdateTime = block.timestamp;
        }
        function SaleEnable(uint256 id,bool trueorfalse)public onlyAdmin
        {
    require(Sale[id].exists,"Sale with this ID not exists");
                Sale[id].enabled = trueorfalse;
    }
    function SaleEnabled(uint256 id)public view returns(bool trueorfalse)
    {
    trueorfalse = Sale[id].enabled;
    }
    struct tx_params
    {
        uint256 num;
        uint256 time;
        uint256 blk;
        address addr;
        uint256 amount;
    }
    mapping(uint256 => mapping(uint256 => tx_params))public Txs;
    mapping(uint256 => uint256)public TxsCount;
    mapping(uint256 => mapping(address => mapping(uint256 => uint256)))public SaleAddrLevelAmount;
    function Allocate(uint256 sale, uint8 level, address addr, uint256 amount, uint8 token)public
    {
    uint256 amount2 = amount * 10**IToken(Sale[sale].tokens[token]).decimals();
    require(Sale[sale].exists == true,"Sale with this ID not exist");
    require(Sale[sale].enabled == true,"Sale with this ID is disabled");
    require(Sale[sale].tokens[token] != address(0),"Sale Token by ID not exists");
        require(amount2 < IERC20(Sale[sale].tokens[token]).balanceOf(_msgSender()),"Not enough tokens to receive");
    require(IERC20(Sale[sale].tokens[token]).allowance(_msgSender(),address(this)) >= amount2,"You need to be allowed to use tokens to pay for this contract [We are wait approve]");
//	require(amount2 == Sale[sale].amount[level] * 10**IToken(Sale[sale].tokens[token]).decimals(),"Amount must be equal Amount for this level");
    require(amount == Sale[sale].amount[level],"Amount must be equal Amount for this level");

    if(Sale[sale].test_mode == false)
    {
    AllocCount += 1;
    AllocSaleCount[sale]    			= AllocSaleCount[sale].add(1);
    AllocSaleAmount[sale]   			= AllocSaleAmount[sale].add(amount);
    AllocSaleLevelCount[sale][level]        	= AllocSaleLevelCount[sale][level].add(1);
    AllocSaleLevelAmount[sale][level]       	= AllocSaleLevelAmount[sale][level].add(amount);
    }

    //uint256 amount_human = amount.div(10**IToken(Sale[sale].tokens[token]).decimals());
        IERC20(Sale[sale].tokens[token]).safeTransferFrom(_msgSender(),AddrVault, amount2);
    emit DDAOAllocate(AllocCount,_msgSender(), addr, sale,level, amount2,amount);

    if(Sale[sale].test_mode == false)
    {
    TxsCount[sale] = TxsCount[sale].add(1);
    Txs[sale][TxsCount[sale]].num = TxsCount[sale];
    Txs[sale][TxsCount[sale]].time	= block.timestamp;
    Txs[sale][TxsCount[sale]].blk	= block.number;
    Txs[sale][TxsCount[sale]].addr	= addr;
    Txs[sale][TxsCount[sale]].amount = amount;

    SaleAddrLevelAmount[sale][addr][level] += amount;
    }
    UpdateTime = block.timestamp;
    }
    function AddrVaultChange(address addr)public onlyAdmin
    {
    AddrVault = addr;
    }
    function SaleListLen()public view returns(uint256)
    {
    return SaleList.length;
    }
    function SaleList2(address addr)public view returns(uint256[] memory)
    {
        string memory s;
        bytes memory b;

    uint256 id;
        uint256 nn;
        uint256 l = SaleList.length;
        uint256[] memory out = new uint256[](2 + l*25);
        out[nn++] = l;
    out[nn++] = UpdateTime;
        if(l>0)
        {
            uint256 i;
            for(i=0;i<l;i++)
            {
	id = SaleList[i];
                out[nn++] = Sale[id].id;
                out[nn++] = Sale[id].exists?1:0;
                out[nn++] = Sale[id].enabled?1:0;
                out[nn++] = Sale[id].test_mode?1:0;
                out[nn++] = Sale[id].hidden?1:0;
                s = Sale[id].name;
                b = bytes(s);
                out[nn++] = uint256(bytes32(b));

                s = Sale[id].url;
                b = bytes(s);
                out[nn++] = uint256(bytes32(b));

                s = Sale[id].img;
                b = bytes(s);
                out[nn++] = uint256(bytes32(b));

                out[nn++] = Sale[id].cap;
                out[nn++] = Sale[id].amount[1];
                out[nn++] = Sale[id].amount[2];
                out[nn++] = Sale[id].amount[3];

                out[nn++] = uint256(uint160(Sale[id].tokens[0]));
	out[nn++] = AllocSaleCount[id];
	out[nn++] = AllocSaleAmount[id];
	out[nn++] = AllocSaleLevelCount[id][1];
	out[nn++] = AllocSaleLevelAmount[id][1];
	out[nn++] = AllocSaleLevelCount[id][2];
	out[nn++] = AllocSaleLevelAmount[id][2];
	out[nn++] = AllocSaleLevelCount[id][3];
	out[nn++] = AllocSaleLevelAmount[id][3];

	out[nn++] = uint256(uint160(addr));
	out[nn++] = SaleAddrLevelAmount[id][addr][1];
	out[nn++] = SaleAddrLevelAmount[id][addr][2];
	out[nn++] = SaleAddrLevelAmount[id][addr][3];
            }
        }
        return out;
    }
    function SaleTokensInfo(uint256 sale,address addr)public view returns(uint256[] memory)
    {
        string memory s;
        bytes memory b;

    uint256 nn;
    uint256 i;
    uint256 l;
    address tkn;
    l = Sale[sale].tokens.length;
    uint256[] memory out = new uint256[](1 + l*5);
    out[nn++] = l;
    for(i=0;i<l;i++)
    {

        tkn = Sale[sale].tokens[i];
        out[nn++] = uint256(uint160(tkn));
        out[nn++] = IToken(tkn).decimals();
        out[nn++] = IToken(tkn).balanceOf(addr);
        out[nn++] = IToken(tkn).allowance(addr,address(this));
            s = IToken(tkn).symbol();
            b = bytes(s);
            out[nn++] = uint256(bytes32(b));

    }
    return out;
    }
    function SaleAmoutView(uint256 sale,uint8 grp)public view returns(uint256)
    {
    return Sale[sale].amount[grp];
    }
}