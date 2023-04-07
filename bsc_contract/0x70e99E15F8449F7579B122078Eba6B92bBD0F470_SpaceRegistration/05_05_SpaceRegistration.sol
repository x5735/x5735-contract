// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;
import "./ISpaceRegistration.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SpaceRegistration is ISpaceRegistration, Ownable {
    event Registered(uint256 indexed spaceId, string slug);
    event Approved(uint256 indexed spaceId, bytes32 merkleRoot, string slug);
    event Unapproved(uint256 indexed spaceId, bytes32 merkleRoot, string slug);

    modifier onlyAdmin(uint256 spaceId) {
        require(
            spaces[spaceId].creator == msg.sender ||
                spaces[spaceId].adminIndices[msg.sender] > 0 ||
                owner() == msg.sender,
            "auth failed"
        );
        _;
    }

    modifier onlyCreator(uint256 spaceId) {
        require(spaces[spaceId].creator == msg.sender || spaces[spaceId].creator == msg.sender, "auth failed");
        _;
    }

    struct MerkleRootState {
        // 1: valid; 2: invalid
        uint128 state;
        uint128 timestamp;
    }

    struct Space {
        address creator;
        string slug;
        mapping(address => uint256) adminIndices;
        address[] adminArray;
        string name;
        string logo;
        mapping(bytes32 => MerkleRootState) roots;
    }

    Space[] private spaces;
    mapping(string=>uint) slugMap;

    function create(string memory _slug, string memory _name, string memory _logo, address[] memory adminArray) public {
        require(slugMap[_slug] == 0, "duplicate");
        Space storage newSpace = spaces.push();
        newSpace.creator = msg.sender;
        newSpace.name = _name;
        newSpace.logo = _logo;
        newSpace.adminArray.push(msg.sender);
        newSpace.slug = _slug;
        slugMap[_slug] = spaces.length - 1;
        for(uint i = 0; i < adminArray.length; i++){
            addAdmin(spaces.length - 1, adminArray[i]);
        }

        emit Registered(spaces.length - 1, _slug);
    }
    
    function addAdmin(uint256 id, address admin) public onlyCreator(id) {
        require(
            spaces[id].adminIndices[msg.sender] == 0 || admin == msg.sender,
            "duplication"
        );

        spaces[id].adminArray.push(admin);
        spaces[id].adminIndices[admin] = spaces[id].adminArray.length - 1;
    }

    function removeAdmin(uint256 id, address admin) public onlyCreator(id) {
        require(spaces[id].adminIndices[msg.sender] != 0, "invalid address");

        spaces[id].adminArray[spaces[id].adminIndices[admin]] = address(0);
        spaces[id].adminIndices[admin] = 0;
    }

    function transferOwnership(uint256 id, address newOwner)
        public
        onlyCreator(id)
    {
        require(newOwner != address(0), "invalid address");
        if (spaces[id].adminIndices[newOwner] != 0) {
            spaces[id].adminArray[spaces[id].adminIndices[newOwner]] = address(
                0
            );
            spaces[id].adminIndices[newOwner] = 0;
        }
        spaces[id].creator = spaces[id].adminArray[0] = newOwner;
    }

    function getAdminArray(uint256 id) public view returns (address[] memory) {
        return spaces[id].adminArray;
    }

    function updateSpaceParam(
        uint256 id,
        string memory _name,
        string memory _logo
    ) public onlyAdmin(id) {
        spaces[id].name = _name;
        spaces[id].logo = _logo;
    }

    function approveMerkleRoot(uint256 id, bytes32 root) public onlyAdmin(id) {
        require(spaces[id].roots[root].state != 1, "duplicate");
        MerkleRootState memory state = MerkleRootState(
            1,
            uint128(block.timestamp)
        );
        spaces[id].roots[root] = state;
        emit Approved(id, root, spaces[id].slug);
    }

    function unapproveMerkleRoot(uint256 id, bytes32 root)
        public
        onlyAdmin(id)
    {
        require(spaces[id].roots[root].state == 1, "invalid merkle");
        spaces[id].roots[root].state = 2;
        emit Unapproved(id, root, spaces[id].slug);
    }

    function spaceParam(uint256 id)
        public
        view
        override
        returns (SpaceParam memory)
    {
        require(spaces[id].creator != address(0), "invalid id");
        return SpaceParam(spaces[id].name, spaces[id].logo);
    }

    function spaceIdBySlug(string memory slug) public view returns(uint ){
        return slugMap[slug];
    }

    function isAdmin(uint256 id, address addr)
        public
        view
        override
        returns (bool)
    {
        return spaces[id].creator == addr || spaces[id].adminIndices[addr] > 0 || owner() == addr;
    }

    function isCreator(uint256 id, address addr)
        public
        view
        override
        returns (bool)
    {
        return spaces[id].creator == addr;
    }

    function verifySignature(
        uint256 id,
        bytes32 message,
        bytes calldata signature
    ) public view override returns (bool) {
        bytes32 _ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", message)
        );
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(signature);
        address addr = ecrecover(_ethSignedMessageHash, v, r, s);
        return isAdmin(id, addr);
    }

    function checkMerkle(
        uint256 id,
        bytes32 root,
        bytes32 leaf,
        bytes32[] calldata _merkleProof
    ) public view override returns (bool) {
        return spaces[id].roots[root].state == 1 && MerkleProof.verify(_merkleProof, root, leaf);
    }

    function splitSignature(bytes memory sig)
        internal
        pure
        returns (
            bytes32 r,
            bytes32 s,
            uint8 v
        )
    {
        require(sig.length == 65, "invalid signature length");

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }
}