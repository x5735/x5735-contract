// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "./CpveTHESolidStaker.sol";
import "../interfaces/ISolidlyGauge.sol";

contract CpveTHE is CpveTHESolidStaker {
    using SafeERC20 for IERC20;

    // Needed addresses
    address[] public mainActiveVoteLps;
    address[] public reserveActiveVoteLps;

    // Events
    event ClaimVeEmissions(
        address indexed user,
        uint256 veMainTokenId,
        uint256 veMainAmount,
        uint256 veReserveTokenId,
        uint256 veReserveAmount
    );
    event RewardsHarvested(uint256 rewardTHE, uint256 rewardCpveTHE);
    event Voted(uint256 tokenId, address[] votes, uint256[] weights);
    event ChargedFees(uint256 callFees, uint256 coFees, uint256 strategistFees);

    constructor(
        string memory _name,
        string memory _symbol,
        address[] memory _manager,
        address _configurator
    )
        CpveTHESolidStaker(
            _name,
            _symbol,
            _manager[0],
            _manager[1],
            _manager[2],
            _manager[3],
            _configurator
        ) {}

    function voteInfo(uint256 _tokenId) external view
        returns (
            address[] memory lpsVoted,
            uint256[] memory votes,
            uint256 lastVoted
        ) {
        uint256 len = mainActiveVoteLps.length;
        uint256 tokenId = mainTokenId;
        if (_tokenId == reserveTokenId) {
            tokenId = reserveTokenId;
            len = reserveActiveVoteLps.length;
        }

        lpsVoted = new address[](len);
        votes = new uint256[](len);
        for (uint i; i < len; i++) {
            lpsVoted[i] = solidVoter.poolVote(tokenId, i);
            votes[i] = solidVoter.votes(tokenId, lpsVoted[i]);
        }
        lastVoted = solidVoter.lastVoted(tokenId);
    }

    function claimVeEmissions() public {
        uint256 _mainAmount = veDist.claim(mainTokenId);
        uint256 _reserveAmount = veDist.claim(reserveTokenId);
        uint256 gap = totalWant() - totalSupply();
        if (gap > 0) {
            uint256 feePercent = configurator.getFee();
            address coFeeRecipient = configurator.coFeeRecipient();
            uint256 feeBal = (gap * feePercent) / MAX_RATE;
            
            if (feeBal > 0) _mint(address(coFeeRecipient), feeBal);
            _mint(address(daoWallet), gap - feeBal);
        }

        emit ClaimVeEmissions(msg.sender, mainTokenId, _mainAmount, reserveTokenId, _reserveAmount);
    }

    function vote(
        uint256 _tokenId,
        address[] calldata _tokenVote,
        uint256[] calldata _weights,
        bool _withHarvest
    ) external onlyVoter {
        // Check to make sure we set up our rewards
        for (uint i; i < _tokenVote.length; i++) {
            require(configurator.lpInitialized(_tokenVote[i]), "Staker: TOKEN_VOTE_INVALID");
        }

        bool isReserve = _tokenId == reserveTokenId;
        if (_withHarvest) {
            harvestVe(isReserve);
        }
        
        if (isReserve) {
            reserveActiveVoteLps = _tokenVote;
        } else {
            mainActiveVoteLps = _tokenVote;
        }

        // We claim first to maximize our voting power.
        claimVeEmissions();
        solidVoter.vote(_tokenId, _tokenVote, _weights);
        emit Voted(_tokenId, _tokenVote, _weights);
    }

    function getRewards(
        uint256 _tokenId,
        address _bribe,
        address[] calldata _tokens,
        ISolidlyRouter.Routes[][] calldata _routes
    ) external nonReentrant onlyManager {
        ISolidlyRouter router = ISolidlyRouter(configurator.router());
        ISolidlyGauge(_bribe).getReward(_tokenId, _tokens);
        for (uint i; i < _routes.length; i++) {
            address tokenFrom = _routes[i][0].from;
            require(_routes[i][_routes[i].length - 1].to == address(want), "Staker: ROUTE_TO_NOT_TOKEN_WANT");
            require(tokenFrom != address(want), "Staker: ROUTE_FROM_IS_TOKEN_WANT");
            uint256 tokenBal = IERC20(tokenFrom).balanceOf(address(this));
            if (tokenBal > 0) {
                IERC20(tokenFrom).safeApprove(address(router), 0);
                IERC20(tokenFrom).safeApprove(address(router), type(uint256).max);
                router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    tokenBal,
                    0,
                    _routes[i],
                    address(this),
                    block.timestamp
                );
            }
        }

        _chargeFees();
    }

    /**
     * @param _type (bool): true - harvestVeReserve, false - harvestVeMain.
    */
    function harvestVe(bool _type) public {
        uint256 tokenId = mainTokenId;
        address[] memory activeVoteLps = mainActiveVoteLps;
        if(_type) {
            tokenId = reserveTokenId;
            activeVoteLps = reserveActiveVoteLps;
        }

        for (uint i; i < activeVoteLps.length; i++) {
            ICpveTHEConfigurator.Gauges memory gauges = configurator.getGauges(activeVoteLps[i]);
            ISolidlyGauge(gauges.bribeGauge).getReward(tokenId, gauges.bribeTokens);
            ISolidlyGauge(gauges.feeGauge).getReward(tokenId, gauges.feeTokens);
            _swapGaugeReward(gauges.bribeTokens, gauges.feeTokens);
        }

        _chargeFees();
    }

    function _chargeFees() internal {
        uint256 rewardTHEBal = IERC20(want).balanceOf(address(this));
        uint256 rewardCpveTHEBal = balanceOf(address(this));
        uint256 feePercent = configurator.getFee();
        address coFeeRecipient = configurator.coFeeRecipient();
        ISolidlyRouter router = ISolidlyRouter(configurator.router());

        if (rewardTHEBal > 0) {
            uint256 feeBal = (rewardTHEBal * feePercent) / MAX_RATE;
            if (feeBal > 0) {
                IERC20(want).safeApprove(address(router), feeBal);
                router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    feeBal,
                    0,
                    configurator.getRoutes(address(want)),
                    address(coFeeRecipient),
                    block.timestamp
                );
                IERC20(want).safeApprove(address(router), 0);
                emit ChargedFees(0, feeBal, 0);
            }

            IERC20(want).safeTransfer(daoWallet, rewardTHEBal - feeBal);
        }

        if (rewardCpveTHEBal > 0) {
            uint256 feeBal = (rewardCpveTHEBal * feePercent) / MAX_RATE;
            if (feeBal > 0) {
                IERC20(address(this)).safeTransfer(address(coFeeRecipient), feeBal);
                emit ChargedFees(0, feeBal, 0);
            }

            IERC20(address(this)).safeTransfer(daoWallet, rewardCpveTHEBal - feeBal);
        }

        emit RewardsHarvested(rewardTHEBal, rewardCpveTHEBal);
    }

    function _swapGaugeReward(address[] memory _bribeTokens, address[] memory _feeTokens) internal {
        ISolidlyRouter router = ISolidlyRouter(configurator.router());
        for (uint j; j < _bribeTokens.length; ++j) {
            address bribeToken = _bribeTokens[j];
            uint256 tokenBal = IERC20(bribeToken).balanceOf(address(this));
            if (tokenBal > 0 && bribeToken != address(want) && bribeToken != address(this)) {
                IERC20(bribeToken).approve(address(router), tokenBal);
                router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    tokenBal,
                    0,
                    configurator.getRoutes(bribeToken),
                    address(this),
                    block.timestamp
                );
            }
        }

        for (uint k; k < _feeTokens.length; ++k) {
            address feeToken = _feeTokens[k];
            uint256 tokenBal = IERC20(feeToken).balanceOf(address(this));
            if (tokenBal > 0 && feeToken != address(want) && feeToken != address(this)) {
                IERC20(feeToken).approve(address(router), tokenBal);
                router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    tokenBal,
                    0,
                    configurator.getRoutes(feeToken),
                    address(this),
                    block.timestamp
                );
            }
        }
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        require(polWallet != address(0),"require to set polWallet address");
        address sender = _msgSender();
        uint256 taxAmount = _chargeTaxTransfer(sender, to, amount);
        _transfer(sender, to, amount - taxAmount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        require(polWallet != address(0),"require to set polWallet address");
        
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);

        uint256 taxAmount = _chargeTaxTransfer(from, to, amount);
        _transfer(from, to, amount - taxAmount);
        return true;
    }

    function _chargeTaxTransfer(address from, address to, uint256 amount) internal returns (uint256) {
        uint256 taxSellingPercent = configurator.hasSellingTax(from, to);
        uint256 taxBuyingPercent = configurator.hasBuyingTax(from, to);
        uint256 taxPercent = taxSellingPercent > taxBuyingPercent ? taxSellingPercent: taxBuyingPercent;
		if(taxPercent > 0) {
            uint256 taxAmount = amount * taxPercent / MAX;
            uint256 amountToDead = taxAmount / 2;
            _transfer(from, configurator.deadWallet(), amountToDead);
            _transfer(from, polWallet, taxAmount - amountToDead);
            return taxAmount;
		}

        return 0;
    }
}