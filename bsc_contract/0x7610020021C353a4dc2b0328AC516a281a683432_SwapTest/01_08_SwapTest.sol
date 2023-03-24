// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../interfaces/IGnosis.sol";
import "../TransferHelper.sol";

contract SwapTest is Ownable, ReentrancyGuard {
    uint256 public constant MIN_AMOUNT = 1e16;
    address public immutable tyz;

    uint256 public timestempInt;
    // after 6 claims, next unlock timestamps always in [6]
    uint32[7] public unlockTimestamps;
    // nonces for signatures to use them only once
    mapping(address => uint256) public nonces;

    address private signer;
    uint32 private claimNumber;

    event FulfillDealer(uint256 tesAmount);
    event SwapToTes(address user, uint256 tesAmount);
    event SwapToTyz(address user, uint256 tesAmount);
    event Claim(uint256 tesCommission, uint256 tesDealer);

    modifier onlyGnosisOwner() {
        require(isOwner(msg.sender) || owner() == msg.sender, "Only gnosis owner");
        _;
    }

    modifier validate(
        bytes32 data,
        uint256 expirationTime,
        bytes calldata signature
    ) {
        require(expirationTime > block.timestamp, "Signature out of time");
        require(
            signer ==
                ECDSA.recover(ECDSA.toEthSignedMessageHash(data), signature),
            "Invalid signature"
        );
        _;
    }

    constructor(
        address _owner,
        address _tyz,
        address _signer,
        uint32[7] memory schedule
    ) {
        require(
            _owner != address(0) && _signer != address(0) && _tyz != address(0),
            "Zero address"
        );
        require(
            schedule[0] > block.timestamp &&
                schedule[1] > schedule[0] &&
                schedule[2] > schedule[1] &&
                schedule[3] > schedule[2] &&
                schedule[4] > schedule[3] &&
                schedule[5] > schedule[4] &&
                schedule[6] > schedule[5],
            "Wrong schedule"
        );
        _transferOwnership(_owner);

        tyz = _tyz;
        signer = _signer;
        unlockTimestamps = schedule;
        timestempInt = block.timestamp;
    }

    /**
     * @notice func for owner to fulfill dealer balance
     * @param tyzAmount with decimals, must be multiple of MIN_AMOUNT
     */
    function fulfillDealer(uint256 tyzAmount) external onlyOwner nonReentrant {
        _swapToTes(tyzAmount);
        emit FulfillDealer(tyzAmount / MIN_AMOUNT);
    }

    /**
     * @notice fun for user to swap his tyz tokens for tes, 1 tyz = 100 tes
     * @param tyzAmount with decimals, must be multiple of MIN_AMOUNT
     */
    function swapToTes(uint256 tyzAmount) external nonReentrant {
        _swapToTes(tyzAmount);
        emit SwapToTes(msg.sender, tyzAmount / MIN_AMOUNT);
    }

    /**
     * @notice fun for user to swap his tes for tyz token, 1 tes = 0.01 tyz
     * @param tesAmount how many tes to swap
     * @param expirationTime timestamp, when signature will die
     * @param signature signed message from backend
     */
    function swapToTyz(
        uint256 tesAmount,
        uint256 expirationTime,
        bytes calldata signature
    )
        external
        nonReentrant
        validate(
            keccak256(
                abi.encodePacked(
                    msg.sender,
                    nonces[msg.sender]++,
                    tesAmount,
                    expirationTime
                )
            ),
            expirationTime,
            signature
        )
    {
        require(tesAmount > 0, "Wrong amount");
        TransferHelper.safeTransfer(tyz, msg.sender, tesAmount * MIN_AMOUNT);
        emit SwapToTyz(msg.sender, tesAmount);
    }

    /**
     * @notice func for owner to claim commission tes from game and swap for tyz,
     * available according to schedule (see unlockTimestamps)
     * @param tesCommission how many tes from commission to swap
     * @param tesDealer how many tes from dealer to swap
     * @param expirationTime timestamp, when signature will die
     * @param signature signed message from backend
     */
    function claim(
        uint256 tesCommission,
        uint256 tesDealer,
        uint256 expirationTime,
        bytes calldata signature
    )
        external
        onlyGnosisOwner
        nonReentrant
        validate(
            keccak256(
                abi.encodePacked(
                    msg.sender,
                    nonces[msg.sender]++,
                    tesCommission,
                    tesDealer,
                    expirationTime
                )
            ),
            expirationTime,
            signature
        )
    {
        (bool available, uint32 number, uint32 nextUnlock) = isAvailable();
        require(available, "Come back later");
        claimNumber = number;
        if (number > 6) {
            unlockTimestamps[6] = nextUnlock;
        }
        uint256 total = tesCommission + tesDealer;
        require(total > 0, "Wrong amount");
        TransferHelper.safeTransfer(tyz, owner(), total * MIN_AMOUNT);
        emit Claim(tesCommission, tesDealer);
    }

    function setTimestamp(uint256 newTimestamp) external {
        timestempInt = newTimestamp;
    }

    /**
     * @notice allow owner to set new signer address
     * @param _signer new signer address
     */
    function setSigner(address _signer) external onlyOwner {
        require(_signer != address(0), "Zero address");
        signer = _signer;
    }

    /**
     * @notice return true if _owner is owner of gnosis multisig, else false
     */
    function isOwner(address _owner) public view returns (bool) {
        return IGnosos(owner()).isOwner(_owner);
    }

    /**
     * @notice return information about claim availability
     * @return available = true if claim can be called now, else = false
     * @return number - number of claim in schedule, after this call
     * @return nextUnlock - next unlock timestamp
     */
    function isAvailable()
        public
        view
        returns (
            bool available,
            uint32 number,
            uint32 nextUnlock
        )
    {
        nextUnlock = claimNumber < 6
            ? unlockTimestamps[claimNumber]
            : unlockTimestamps[6];
        for (
            number = claimNumber;
            available == false && timestempInt >= nextUnlock;
            ++number
        ) {
            if (timestempInt < nextUnlock + 5 days) {
                available = true;
            }
            if (number < 6) {
                nextUnlock = unlockTimestamps[number + 1];
            } else {
                nextUnlock += number % 4 == 0 ? 366 days : 365 days;
            }
        }
    }

    /**
     * @notice internal func for swapToTes and fulfillDealer
     * check tyzAmount and collect tokens
     */
    function _swapToTes(uint256 tyzAmount) internal {
        require(tyzAmount > 0 && tyzAmount % MIN_AMOUNT == 0, "Wrong amount");
        TransferHelper.safeTransferFrom(
            tyz,
            msg.sender,
            address(this),
            tyzAmount
        );
    }
}