// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./IMetobadgeFactory.sol";
import "./ISpaceRegistration.sol";

contract MetobadgeFactory is IMetobadgeFactory, Ownable {
    event Issue(uint256 indexed typeId, uint256 indexed spaceId);
    event Update(uint256 indexed typeId);

    ISpaceRegistration spaceRegistration;

    constructor(address _spaceRegistration) public {
        spaceRegistration = ISpaceRegistration(_spaceRegistration);
    }

    Collection[] private collections;
    mapping(uint256 => uint256[]) private spaceAssets;

    function issue(
        uint256 spaceId,
        string memory name,
        string memory description,
        uint256 lifespan,
        string memory signerLogo,
        string memory signerName
    ) public {
        require(spaceRegistration.isAdmin(spaceId, msg.sender), "auth failed");
        Collection storage _collection = collections.push();
        _collection.spaceId = spaceId;
        _collection.lifespan = lifespan;
        _collection.description = description;
        _collection.name = name;

        _collection.signerLogo = signerLogo;
        _collection.signerName = signerName;

        spaceAssets[spaceId].push(collections.length - 1);
        emit Issue(collections.length - 1, spaceId);
    }

    function update(
        uint256 id,
        string memory name,
        string memory description,
        uint256 lifespan,
        string memory signerLogo,
        string memory signerName
    ) public {
        require(
            spaceRegistration.isAdmin(collections[id].spaceId, msg.sender),
            "auth failed"
        );
        Collection storage _collection = collections[id];
        _collection.description = description;
        _collection.lifespan = lifespan;
        _collection.name = name;
        _collection.signerLogo = signerLogo;
        _collection.signerName = signerName;

        emit Update(id);
    }

    function updateSpaceRegistration(address addr) public onlyOwner {
        spaceRegistration = ISpaceRegistration(addr);
    }

    function collection(uint256 id)
        public
        view
        override
        returns (Collection memory)
    {
        require(id < collections.length, "invalid id");
        return collections[id];
    }

    function collectionsBySpace(uint256 spaceId)
        public
        view
        returns (uint256[] memory)
    {
        return spaceAssets[spaceId];
    }
    
    function setSpaceRegistration(address _spaceRegistration) public onlyOwner {
        spaceRegistration = ISpaceRegistration(_spaceRegistration);
    }

    function total() public view returns (uint256) {
        return collections.length;
    }
}