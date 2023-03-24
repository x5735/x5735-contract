// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import "./HedgepieAccessControlled.sol";
import "../interfaces/IHedgepieAuthority.sol";

contract PathFinder is HedgepieAccessControlled {
    // router information
    mapping(address => bool) public routers;

    // router => inToken => outToken => paths
    mapping(address => mapping(address => mapping(address => address[])))
        public paths;

    constructor(
        address _hedgepieAuthority
    ) HedgepieAccessControlled(IHedgepieAuthority(_hedgepieAuthority)) {}

    event RouterAdded(address indexed router, bool value);
    event RouterRemoved(address indexed router, bool value);

    /**
     * @notice Set paths from inToken to outToken
     * @param _router swap router address
     * @param _value add or remove router
     */
    function setRouter(address _router, bool _value) external onlyPathManager {
        require(_router != address(0), "Invalid router address");
        routers[_router] = _value;

        if (_value) emit RouterAdded(_router, _value);
        else emit RouterRemoved(_router, _value);
    }

    /**
     * @notice Get path
     * @param _router router address
     * @param _inToken token address of inToken
     * @param _outToken token address of outToken
     */
    function getPaths(
        address _router,
        address _inToken,
        address _outToken
    ) public view returns (address[] memory) {
        require(routers[_router], "Router not registered");
        require(
            paths[_router][_inToken][_outToken].length > 1,
            "Path length is not valid"
        );
        require(
            paths[_router][_inToken][_outToken][0] == _inToken,
            "Path is not existed"
        );
        require(
            paths[_router][_inToken][_outToken][
                paths[_router][_inToken][_outToken].length - 1
            ] == _outToken,
            "Path is not existed"
        );

        return paths[_router][_inToken][_outToken];
    }

    /**
     * @notice Set paths from inToken to outToken
     * @param _router swap router address
     * @param _inToken token address of inToken
     * @param _outToken token address of outToken
     * @param _paths swapping paths
     */
    function setPath(
        address _router,
        address _inToken,
        address _outToken,
        address[] memory _paths
    ) external onlyPathManager {
        require(routers[_router], "Router not registered");
        require(_paths.length > 1, "Invalid paths length");
        require(_inToken == _paths[0], "Invalid inToken address");
        require(
            _outToken == _paths[_paths.length - 1],
            "Invalid inToken address"
        );

        uint8 i;
        for (i; i < _paths.length; i++) {
            if (i < paths[_router][_inToken][_outToken].length) {
                paths[_router][_inToken][_outToken][i] = _paths[i];
            } else {
                paths[_router][_inToken][_outToken].push(_paths[i]);
            }
        }

        if (paths[_router][_inToken][_outToken].length > _paths.length)
            for (
                i = 0;
                i < paths[_router][_inToken][_outToken].length - _paths.length;
                i++
            ) paths[_router][_inToken][_outToken].pop();
    }
}