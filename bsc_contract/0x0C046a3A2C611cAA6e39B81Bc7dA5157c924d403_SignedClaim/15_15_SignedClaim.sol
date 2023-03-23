// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "./ClaimBase.sol";

contract SignedClaimStorage is ClaimStorage {
    uint256 public requiredSignatures;
}

contract SignedClaim is
    Initializable,
    AccessControlUpgradeable,
    SignedClaimStorage,
    ClaimBase
{
    using ECDSA for bytes32;

    bytes32 public constant CLAIM_SIGNER_ROLE = keccak256("CLAIM_SIGNER_ROLE");

    event RequiredSignaturesChanged(uint256 requiredSignatures);

    function initialize(
        address token_,
        address tokenHolder_,
        address claimSigner_
    ) public initializer {
        __AccessControl_init();

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(CLAIM_SIGNER_ROLE, claimSigner_);

        setTokenInternal(token_);
        setTokenHolderInternal(tokenHolder_);

        // Set Defaults
        setExchangeRateInternal(1e18);
        requiredSignatures = 1;
    }

    /* Admin Functions */
    function _setConfiguration(
        address token_,
        address tokenHolder_
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        setTokenInternal(token_);
        setTokenHolderInternal(tokenHolder_);
    }

    function _setExchangeRate(
        uint256 exchangeRateMantissa_
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        setExchangeRateInternal(exchangeRateMantissa_);
    }

    function _setRequiredSignatures(
        uint256 requiredSignatures_
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        setRequiredSignaturesInternal(requiredSignatures_);
    }

    /* Public Functions */
    function claim(
        uint256 cumulatedAmount,
        uint256 expire,
        bytes[] memory signatures
    ) public {
        require(expire > block.timestamp, "SignedClaim: CLAIM_EXPIRED");

        checkNSignaturesInternal(
            abi.encode(_msgSender(), cumulatedAmount, expire),
            signatures,
            requiredSignatures
        );

        claimAmountInternal(_msgSender(), cumulatedAmount);
    }

    /* Internal functions */
    function checkNSignaturesInternal(
        bytes memory data,
        bytes[] memory signatures,
        uint256 _requiredSignatures
    ) internal view {
        require(_requiredSignatures > 0, "SignedClaim: NO_REQUIRED_SIGNATURES");
        require(
            signatures.length >= _requiredSignatures,
            "SignedClaim: NOT_ENOUGH_SIGNATURES"
        );

        bytes32 message = keccak256(data).toEthSignedMessageHash();

        address lastSigner = address(0);
        for (uint256 i = 0; i < _requiredSignatures; i++) {
            address signer = message.recover(signatures[i]);

            require(
                hasRole(CLAIM_SIGNER_ROLE, signer),
                "SignedClaim: INVALID_SIGNATURE"
            );

            // prevent duplicate signatures
            require(
                signer > lastSigner,
                "SignedClaim: SIGNERS_SHOULD_IN_ORDER"
            );
            lastSigner = signer;
        }
    }

    function setRequiredSignaturesInternal(
        uint256 requiredSignatures_
    ) internal {
        requiredSignatures = requiredSignatures_;

        emit RequiredSignaturesChanged(requiredSignatures);
    }
}