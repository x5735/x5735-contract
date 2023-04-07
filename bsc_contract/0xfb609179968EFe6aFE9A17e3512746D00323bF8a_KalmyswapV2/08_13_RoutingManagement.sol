//SPDX-License-Identifier: MIT
pragma solidity 0.5.17;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "./interfaces/IKalmarTradingRoute.sol";

contract RoutingManagement is Ownable {
    /**
    * @dev Struct of trading route
    * @param name Name of trading route.
    * @param enable The flag of trading route to check is trading route enable.
    * @param route The address of trading route.
    */
    struct Route {
      string name;
      bool enable;
      IKalmarTradingRoute route;
    }

    event AddedBatchTradingRoute(
        address indexed addedBy,
        string[] name,
        address[] routingAddress,
        uint256 indexed length
    );

    event AddedTradingRoute(
        address indexed addedBy,
        string name,
        IKalmarTradingRoute indexed routingAddress,
        uint256 indexed index
    );

    event EnabledTradingRoute(
        address indexed enabledBy,
        string name,
        IKalmarTradingRoute indexed routingAddress,
        uint256 indexed index
    );

    event DisabledTradingRoute(
        address indexed disabledBy,
        string name,
        IKalmarTradingRoute indexed routingAddress,
        uint256 indexed index
    );

    Route[] public tradingRoutes; // list of trading routes

    modifier onlyTradingRouteEnabled(uint _index) {
        require(tradingRoutes[_index].enable == true, "This trading route is disabled");
        _;
    }

    modifier onlyTradingRouteDisabled(uint _index) {
        require(tradingRoutes[_index].enable == false, "This trading route is enabled");
        _;
    }

    function addBatchTradingRoute(
        string[] memory _name,
        address[] memory _routingAddress
    )
      public
      onlyOwner
    {
        require(_name.length == _routingAddress.length, "Invalid length!");
        for (uint256 i = 0; i < _routingAddress.length; i++) {
            tradingRoutes.push(Route({
            name: _name[i],
            enable: true,
            route: IKalmarTradingRoute(_routingAddress[i])
        }));
        }
        
        emit AddedBatchTradingRoute(msg.sender, _name, _routingAddress, _routingAddress.length);
    }

    /**
    * @dev Function for adding new trading route
    * @param _name Name of trading route.
    * @param _routingAddress The address of trading route.
    * @return length of trading routes.
    */
    function addTradingRoute(
        string memory _name,
        IKalmarTradingRoute _routingAddress
    )
      public
      onlyOwner
    {
        tradingRoutes.push(Route({
            name: _name,
            enable: true,
            route: _routingAddress
        }));
        emit AddedTradingRoute(msg.sender, _name, _routingAddress, tradingRoutes.length - 1);
    }

    /**
    * @dev Function for disable trading route by index
    * @param _index The uint256 of trading route index.
    * @return length of trading routes.
    */
    function disableTradingRoute(
        uint256 _index
    )
        public
        onlyOwner
        onlyTradingRouteEnabled(_index)
    {
        tradingRoutes[_index].enable = false;
        emit DisabledTradingRoute(msg.sender, tradingRoutes[_index].name, tradingRoutes[_index].route, _index);
    }

    /**
    * @dev Function for enale trading route by index
    * @param _index The uint256 of trading route index.
    * @return length of trading routes.
    */
    function enableTradingRoute(
        uint256 _index
    )
        public
        onlyOwner
        onlyTradingRouteDisabled(_index)
    {
        tradingRoutes[_index].enable = true;
        emit EnabledTradingRoute(msg.sender, tradingRoutes[_index].name, tradingRoutes[_index].route, _index);
    }

    /**
    * @dev Function for get amount of trading route
    * @return Amount of trading routes.
    */
    function allRoutesLength() public view returns (uint256) {
        return tradingRoutes.length;
    }

    /**
    * @dev Function for get enable status of trading route
    * @param _index The uint256 of trading route index.
    * @return enable status of trading route.
    */
    function isTradingRouteEnabled(uint256 _index) public view returns (bool) {
        return tradingRoutes[_index].enable;
    }
}