// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../utils/NameVersion.sol";
import "../token/IERC20.sol";
import "../token/IDToken.sol";
import "../pool/IPool.sol";
import "../library/SafeERC20.sol";
import "../library/SafeMath.sol";
import "./BrokerStorage.sol";
import "./IClient.sol";
import "../test/Log.sol";

contract BrokerImplementation is BrokerStorage, NameVersion {
    using Log for *;

    event SetRouter(address router, bool isActive);

    event TradeWithMargin(
        address indexed user,
        address indexed pool,
        address asset,
        int256 amount,
        string symbolName,
        int256 tradeVolume,
        int256 priceLimit,
        address client
    );

    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using SafeMath for int256;

    int256 constant ONE = 1e18;

    uint256 constant UMAX = type(uint256).max / 1e18;

    address public immutable clientTemplate;

    address public immutable clientImplementation;

    address public immutable tokenB0;

    uint256 public immutable decimalsTokenB0;

    constructor(
        address clientTemplate_,
        address clientImplementation_,
        address tokenB0_
    ) NameVersion("BrokerImplementation", "3.0.3") {
        clientTemplate = clientTemplate_;
        clientImplementation = clientImplementation_;
        tokenB0 = tokenB0_;
        decimalsTokenB0 = IERC20(tokenB0_).decimals();
    }

    function setRouter(address router_, bool isActive) external _onlyAdmin_ {
        isRouter[router_] = isActive;
        emit SetRouter(router_, isActive);
    }

    function addMargin(
        address account,
        address pool,
        bytes32 symbolId,
        address asset,
        int256 amount
    ) external payable {
        require(isRouter[msg.sender], "broker: only router");
        address client = clients[account][pool][symbolId][asset];
        if (client == address(0)) {
            client = _clone(clientTemplate);
            clients[account][pool][symbolId][asset] = client;
        }
        if (amount > 0) {
            uint256 uAmount;
            if (asset == address(0)) {
                uAmount = msg.value;
                _transfer(address(0), client, uAmount);
            } else {
                uAmount = amount.itou();
                IERC20(asset).safeTransferFrom(account, client, uAmount);
            }
            IClient(client).addMargin(pool, asset, uAmount, new IPool.OracleSignature[](0));
        }
    }

    function removeMargin(
        address account,
        address pool,
        address asset,
        int256 amount,
        address client,
        bool closed
    ) external {
        require(isRouter[msg.sender], "broker: only router");
        IPool.OracleSignature[] memory oracleSig = new IPool.OracleSignature[](0);
        if (closed) {
            IClient(client).removeMargin(pool, asset, UMAX - 1, oracleSig);
            uint256 balance = asset == address(0)
                ? client.balance
                : IERC20(asset).balanceOf(client);
            IClient(client).transfer(asset, account, balance);
            if (asset != tokenB0) {
                IPoolComplement.TdInfo memory tdInfo = _getTdInfo(pool, client);
                if (tdInfo.amountB0 >= ONE / int256(10 ** decimalsTokenB0)) {
                    IClient(client).removeMargin(
                        pool,
                        tokenB0,
                        UMAX,
                        oracleSig
                    );
                    balance = IERC20(tokenB0).balanceOf(client);
                    IClient(client).transfer(tokenB0, account, balance);
                }
            }
        } else if (amount < 0) {
            IClient(client).removeMargin(
                pool,
                asset,
                (-amount).itou(),
                oracleSig
            );
            uint256 balance = asset == address(0)
                ? client.balance
                : IERC20(asset).balanceOf(client);
            IClient(client).transfer(asset, account, balance);
        }
    }

    function emitTradeEvent(
        address account,
        address pool,
        address asset,
        int256 amount,
        string memory symbolName,
        int256 tradeVolume,
        int256 priceLimit,
        address client
    ) external {
        require(isRouter[msg.sender], "broker: only router");
        emit TradeWithMargin(
            account,
            pool,
            asset,
            amount,
            symbolName,
            tradeVolume,
            priceLimit,
            client
        );
    }

    //    function tradeWithMargin(
    //        address account,
    //        address pool,
    //        address asset,
    //        int256 amount,
    //        string memory symbolName,
    //        int256 tradeVolume,
    //        int256 priceLimit
    //    ) external payable {
    //        require(isRouter[msg.sender], "broker: only router");
    //        IPool.OracleSignature[] memory oracleSig = new IPool.OracleSignature[](0);
    //        bytes32 symbolId = keccak256(abi.encodePacked(symbolName));
    //        address client = clients[account][pool][symbolId][asset];
    //
    //        if (client == address(0)) {
    //            client = _clone(clientTemplate);
    //            clients[account][pool][symbolId][asset] = client;
    //        }
    //
    //        // addMargin
    //        if (amount > 0) {
    //            uint256 uAmount;
    //            if (asset == address(0)) {
    //                uAmount = msg.value;
    //                _transfer(address(0), client, uAmount);
    //            } else {
    //                uAmount = amount.itou();
    //                IERC20(asset).safeTransferFrom(account, client, uAmount);
    //            }
    //            IClient(client).addMargin(pool, asset, uAmount, oracleSig);
    //        }
    //
    //        bool closed;
    //
    //        // trade
    //        if (tradeVolume != 0) {
    //            IClient(client).trade(pool, symbolName, tradeVolume, priceLimit);
    //            ISymbolComplement.Position memory pos = getPosition(account, pool, symbolId, asset);
    //            if (pos.volume == 0) {
    //                closed = true;
    //            }
    //        }
    //        account.log("tradeWithMargin.3");
    //
    //        // removeMargin
    //        if (closed) {
    //            IClient(client).removeMargin(pool, asset, UMAX - 1, oracleSig);
    //            uint256 balance = asset == address(0) ? client.balance : IERC20(asset).balanceOf(client);
    //            IClient(client).transfer(asset, account, balance);
    //            account.log("tradeWithMargin.3.1");
    //
    //            if (asset != tokenB0) {
    //                IPoolComplement.TdInfo memory tdInfo = _getTdInfo(pool, client);
    //                if (tdInfo.amountB0 >= ONE / int256(10**decimalsTokenB0)) {
    //                    IClient(client).removeMargin(pool, tokenB0, UMAX, oracleSig);
    //                    balance = IERC20(tokenB0).balanceOf(client);
    //                    IClient(client).transfer(tokenB0, account, balance);
    //                }
    //                account.log("tradeWithMargin.3.2");
    //            }
    //        } else if (amount < 0) {
    //            IClient(client).removeMargin(pool, asset, (-amount).itou(), oracleSig);
    //            uint256 balance = asset == address(0) ? client.balance : IERC20(asset).balanceOf(client);
    //            IClient(client).transfer(asset, account, balance);
    //            account.log("tradeWithMargin.3.3");
    //        }
    //        account.log("tradeWithMargin.4");
    //
    //        emit TradeWithMargin(account, pool, asset, amount, symbolName, tradeVolume, priceLimit, client);
    //    }

    //================================================================================
    // View functions
    //================================================================================
    function _getTdInfo(
        address pool,
        address client
    ) internal view returns (IPoolComplement.TdInfo memory tdInfo) {
        IDToken pToken = IDToken(IPoolComplement(pool).pToken());
        uint256 pTokenId = pToken.getTokenIdOf(client);
        tdInfo = IPoolComplement(pool).tdInfos(pTokenId);
    }

    function getPositions(
        address account,
        address pool,
        string[] memory symbols,
        address[] memory assets
    ) external view returns (ISymbolComplement.Position[] memory positions) {
        positions = new ISymbolComplement.Position[](
            symbols.length * assets.length
        );
        for (uint256 i = 0; i < symbols.length; i++) {
            bytes32 symbolId = keccak256(abi.encodePacked(symbols[i]));
            for (uint256 j = 0; j < assets.length; j++) {
                positions[i * assets.length + j] = getPosition(
                    account,
                    pool,
                    symbolId,
                    assets[j]
                );
            }
        }
    }

    function getPosition(
        address account,
        address pool,
        bytes32 symbolId,
        address asset
    ) public view returns (ISymbolComplement.Position memory position) {
        address client = clients[account][pool][symbolId][asset];
        if (client != address(0)) {
            IDToken pToken = IDToken(IPoolComplement(pool).pToken());
            uint256 pTokenId = pToken.getTokenIdOf(client);
            if (pTokenId != 0) {
                address symbol = ISymbolManagerComplement(
                    IPoolComplement(pool).symbolManager()
                ).symbols(symbolId);
                if (symbol != address(0)) {
                    position = ISymbolComplement(symbol).positions(pTokenId);
                }
            }
        }
    }

    function getUserStatuses(
        address account,
        address pool,
        string[] memory symbols,
        address[] memory assets
    ) external view returns (uint256[] memory statuses) {
        statuses = new uint256[](symbols.length * assets.length);
        for (uint256 i = 0; i < symbols.length; i++) {
            bytes32 symbolId = keccak256(abi.encodePacked(symbols[i]));
            for (uint256 j = 0; j < assets.length; j++) {
                statuses[i * assets.length + j] = getUserStatus(
                    account,
                    pool,
                    symbolId,
                    assets[j]
                );
            }
        }
    }

    // Return value:
    // 1: User never traded, no client
    // 2: User is holding a position
    // 3: User closed position normally
    // 4: User is liquidated
    // 0: Wrong query, e.g. wrong symbolId etc.
    function getUserStatus(
        address account,
        address pool,
        bytes32 symbolId,
        address asset
    ) public view returns (uint256 status) {
        address client = clients[account][pool][symbolId][asset];
        if (client == address(0)) {
            status = 1;
        } else {
            IDToken pToken = IDToken(IPoolComplement(pool).pToken());
            uint256 pTokenId = pToken.getTokenIdOf(client);
            if (pTokenId != 0) {
                address symbol = ISymbolManagerComplement(
                    IPoolComplement(pool).symbolManager()
                ).symbols(symbolId);
                if (symbol != address(0)) {
                    ISymbolComplement.Position memory p = ISymbolComplement(
                        symbol
                    ).positions(pTokenId);
                    if (p.volume != 0) {
                        status = 2;
                    } else {
                        status = p.cumulativeFundingPerVolume != 0 ? 3 : 4;
                    }
                }
            }
        }
    }

    //================================================================================
    // Admin functions
    //================================================================================
    function claimRewardAsLpVenus(
        address pool,
        address[] memory clients
    ) external _onlyAdmin_ {
        for (uint256 i = 0; i < clients.length; i++) {
            IClient(clients[i]).claimRewardAsLpVenus(pool);
        }
    }

    function claimRewardAsTraderVenus(
        address pool,
        address[] memory clients
    ) external _onlyAdmin_ {
        for (uint256 i = 0; i < clients.length; i++) {
            IClient(clients[i]).claimRewardAsTraderVenus(pool);
        }
    }

    function claimRewardAsLpAave(
        address pool,
        address[] memory clients
    ) external _onlyAdmin_ {
        for (uint256 i = 0; i < clients.length; i++) {
            IClient(clients[i]).claimRewardAsLpAave(pool);
        }
    }

    function claimRewardAsTraderAave(
        address pool,
        address[] memory clients
    ) external _onlyAdmin_ {
        for (uint256 i = 0; i < clients.length; i++) {
            IClient(clients[i]).claimRewardAsTraderAave(pool);
        }
    }

    function transfer(
        address asset,
        address to,
        uint256 amount
    ) external _onlyAdmin_ {
        _transfer(asset, to, amount);
    }

    //================================================================================
    // Internal functions
    //================================================================================

    function _clone(address source) internal returns (address target) {
        bytes20 sourceBytes = bytes20(source);
        assembly {
            let c := mload(0x40)
            mstore(
                c,
                0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
            )
            mstore(add(c, 0x14), sourceBytes)
            mstore(
                add(c, 0x28),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )
            target := create(0, c, 0x37)
        }
    }

    // amount in asset's own decimals
    function _transfer(address asset, address to, uint256 amount) internal {
        if (asset == address(0)) {
            (bool success, ) = payable(to).call{value: amount}("");
            require(success, "BrokerImplementation.transfer: send ETH fail");
        } else {
            IERC20(asset).safeTransfer(to, amount);
        }
    }
}

interface IPoolComplement {
    function pToken() external view returns (address);

    function symbolManager() external view returns (address);

    struct TdInfo {
        address vault;
        int256 amountB0;
    }

    function tdInfos(uint256 pTokenId) external view returns (TdInfo memory);
}

interface ISymbolManagerComplement {
    function symbols(bytes32 symbolId) external view returns (address);
}

interface ISymbolComplement {
    struct Position {
        int256 volume;
        int256 cost;
        int256 cumulativeFundingPerVolume;
    }

    function positions(
        uint256 pTokenId
    ) external view returns (Position memory);
}