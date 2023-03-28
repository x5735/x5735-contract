/**
 *Submitted for verification at BscScan.com on 2023-03-27
*/

pragma solidity ^0.6.6;


contract test {

    address public a;
    address public b;
    uint256 public c;
    uint256 public d;
    uint256 public e;
    uint256 public f;
    uint256 public g;
    uint256 public h;
    uint256 public i;
    uint256 public j;
    uint256 public k;
    bool public l;
    bool public m;    

    mapping(address => address) public n;

    constructor () public {
        a = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
        b = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
        c = 1;
        d = 2;
        e = 3;
        f = 4;
        g = 5;
        h = 6;
        i = 7;
        j = 8;
        k = 9;
        l = true;
        m = false;
        n[0x10ED43C718714eb63d5aA57B78B54704E256024E] = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
        n[msg.sender] = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    }

    function read() public view returns (
        address,
        address,
        uint256[] memory,
        bool,
        bool,
        address,
        address
    ) {

        uint256[] memory arr = new uint256[](9);

        arr[0] = c;
        arr[1] = d;
        arr[2] = e;
        arr[3] = f;
        arr[4] = g;
        arr[5] = h;
        arr[6] = i;
        arr[7] = j;
        arr[8] = k;

        return (
            a,
            b,
            arr,
            l,
            m,
            n[0x10ED43C718714eb63d5aA57B78B54704E256024E],
            n[msg.sender]
        );
    }

}