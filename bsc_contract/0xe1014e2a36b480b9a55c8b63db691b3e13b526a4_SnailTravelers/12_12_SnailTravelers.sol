// contracts/SnailTravelers.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract SnailTravelers is Initializable, ERC721Upgradeable {
  /*//////////////////////////////////////////////////////////////
                    ERC721 BALANCE/OWNER STORAGE
  //////////////////////////////////////////////////////////////*/

  uint256 public mintPrice;
  uint256 public totalSupply;
  uint256 public maxSupply;
  SalePhase public phase;

  string internal baseTokenUri;
  address private _adminSigner;
  address payable private _owner;
  address payable private _rewards;

  uint256 public rewardFee;
  uint256 public breedPrice;
  uint256 public breedFee;
  mapping(address => uint256) private addressToPreSaleMints;

  enum SalePhase {
    Closed,
    PreSale,
    PublicSale
  }

  /*//////////////////////////////////////////////////////////////
                        TIER CONFIG
  //////////////////////////////////////////////////////////////*/

  enum Tier {
    Traveler,
    Trainer,
    Breed
  }

  enum Level {
    Genesis,
    Newbie,
    Medium,
    Starter,
    Advanced,
    Platinum
  }

  struct LevelConfig {
    SalePhase phase;
    uint256 price;
    uint256 maxPerWallet;
    mapping(address => uint256) ownedPerWallet;
    uint256 maxSupply;
    uint256 totalSupply;
  }

  struct TierConfig {
    mapping(Level => LevelConfig) levelConfig;
    uint256 maxSupply;
    uint256 totalSupply;
  }

  mapping(Tier => TierConfig) public tierConfig;

  /*//////////////////////////////////////////////////////////////
                        TRAVELER CONFIG
  //////////////////////////////////////////////////////////////*/

  struct TravelerInfo {
    Tier tier;
    Level level;
    address owner;
  }
  mapping(uint256 => TravelerInfo) public travelerInfo;

  /*//////////////////////////////////////////////////////////////
                        ACCOUNT CONFIG
  //////////////////////////////////////////////////////////////*/

  struct Nonce {
    uint256 discount;
    uint256 upgrade;
  }

  mapping(address => Nonce) private nonces;

  enum ActionType {
    Mint,
    Invalidate,
    Transfer
  }

  // NEW VARIABLES MUST BE ADDED BELLOW EXISTING ONE

  /*//////////////////////////////////////////////////////////////
                                EVENTS
  //////////////////////////////////////////////////////////////*/

  event TravelersEvent(
    address indexed from,
    address indexed owner,
    ActionType action,
    uint256 id,
    Tier tier,
    Level level,
    uint256 indexed blockNumber
  );

  event Breeded(
    address indexed owner,
    uint256 id,
    uint256 price,
    address indexed parent1,
    address indexed parent2,
    uint256 parent1Percentage,
    uint256 parent2Percentage
  );

  /*//////////////////////////////////////////////////////////////
                  CONSTRUCTOR & MODIFIERS
  //////////////////////////////////////////////////////////////*/

  function initialize(
    address adminSigner,
    address payable owner,
    address payable rewards
  ) public initializer {
    __ERC721_init("SnailTravelers", "SNLT");
    // Config
    _adminSigner = adminSigner;
    _owner = owner;
    _rewards = rewards;

    // Fees
    rewardFee = 10;
    breedFee = 10;
  }

  // Use this to intialize a contract after upgrading it
  function initializeUpgrade() public onlyOwner {
    // Travelers
    tierConfig[Tier.Traveler].maxSupply = 141;
    tierConfig[Tier.Traveler].totalSupply = 3; // TBD
    //    Genesis
    tierConfig[Tier.Traveler].levelConfig[Level.Genesis].price = 0.2 ether;
    tierConfig[Tier.Traveler].levelConfig[Level.Genesis].totalSupply = 9; // TBD
    //    Normal
    tierConfig[Tier.Traveler].levelConfig[Level.Platinum].price = 0.2 ether;
    tierConfig[Tier.Traveler].levelConfig[Level.Platinum].totalSupply = 0; // TBD

    // Trainers
    tierConfig[Tier.Trainer].maxSupply = 0;
    tierConfig[Tier.Trainer].totalSupply = 22;
    //    Newbie
    tierConfig[Tier.Trainer].levelConfig[Level.Newbie].price = 0 ether;
    tierConfig[Tier.Trainer].levelConfig[Level.Newbie].maxPerWallet = 1;
    tierConfig[Tier.Trainer].levelConfig[Level.Newbie].maxSupply = 3000;
    tierConfig[Tier.Trainer].levelConfig[Level.Newbie].totalSupply = 15; // TBD
    //    Starter
    tierConfig[Tier.Trainer].levelConfig[Level.Starter].price = 0.05 ether;
    tierConfig[Tier.Trainer].levelConfig[Level.Starter].maxSupply = 3000;
    tierConfig[Tier.Trainer].levelConfig[Level.Starter].totalSupply = 1; // TBD
    //    Medium
    tierConfig[Tier.Trainer].levelConfig[Level.Medium].price = 0.1 ether;
    tierConfig[Tier.Trainer].levelConfig[Level.Medium].maxSupply = 3000;
    tierConfig[Tier.Trainer].levelConfig[Level.Medium].totalSupply = 0; // TBD
    //    Advanced
    tierConfig[Tier.Trainer].levelConfig[Level.Advanced].price = 0.15 ether;
    tierConfig[Tier.Trainer].levelConfig[Level.Advanced].maxSupply = 3000;
    tierConfig[Tier.Trainer].levelConfig[Level.Advanced].totalSupply = 0; // TBD

    // Breed
    tierConfig[Tier.Breed].totalSupply = 0;
    //    Normal
    tierConfig[Tier.Breed].levelConfig[Level.Platinum].price = 0.3 ether;
  }

  modifier ensureAvailabilityFor(Tier tier, Level level) {
    uint256 _maxSupply = getMaxSupply(tier, level);
    uint256 _totalSupply = getTotalSupply(tier, level);
    require(1 + _totalSupply <= _maxSupply, "SOLD_OUT");
    _;
  }

  modifier ensureMaxPerWallet(Tier tier, Level level) {
    require(
      tierConfig[tier].levelConfig[level].maxPerWallet == 0 ||
        tierConfig[tier].levelConfig[level].ownedPerWallet[msg.sender] <
        tierConfig[tier].levelConfig[level].maxPerWallet,
      "MAX_REACHED"
    );
    _;
  }

  modifier ensurePhase(Tier tier, Level level) {
    require(
      tierConfig[tier].levelConfig[level].phase == SalePhase.PublicSale,
      "SALE_CLOSED"
    );
    _;
  }

  modifier validateEthPayment(Tier tier, Level level) {
    require(
      tierConfig[tier].levelConfig[level].price == msg.value,
      "WRONG_AMOUNT_PAYED"
    );
    _;
  }

  modifier onlyOwner() {
    require(_owner == msg.sender, "NOT_OWNER");
    _;
  }

  modifier ensureLevel(Tier tier, Level level) {
    if (tier == Tier.Traveler) {
      require(level == Level.Platinum || level == Level.Genesis, "WRONG_LEVEL");
    } else if (tier == Tier.Trainer) {
      require(
        level == Level.Newbie ||
          level == Level.Starter ||
          level == Level.Medium ||
          level == Level.Advanced,
        "WRONG_LEVEL"
      );
    } else if (tier == Tier.Breed) {
      require(level == Level.Platinum, "WRONG_LEVEL");
    }
    _;
  }

  /*//////////////////////////////////////////////////////////////
                        COUPONS
  //////////////////////////////////////////////////////////////*/

  struct Coupon {
    bytes32 r;
    bytes32 s;
    uint8 v;
  }

  enum CouponType {
    PreSale,
    BreedSale,
    Discount,
    Upgrade
  }

  function _isVerifiedCoupon(
    bytes32 digest,
    Coupon memory coupon
  ) internal view returns (bool) {
    address signer = ecrecover(digest, coupon.v, coupon.r, coupon.s);
    require(signer != address(0), "ECDSA: invalid signature");

    return signer == _adminSigner;
  }

  function validateDiscount(
    string memory uuid,
    Tier tier,
    Level level,
    uint256 discount,
    uint256 nonce,
    Coupon memory coupon
  ) internal view {
    require(nonces[msg.sender].discount == nonce, "COUPON_USED");
    bytes32 digest = keccak256(
      abi.encode(
        CouponType.Discount,
        uuid,
        tier,
        level,
        discount,
        nonce,
        msg.sender
      )
    );
    require(_isVerifiedCoupon(digest, coupon), "INVALID_COUPON");
  }

  /*//////////////////////////////////////////////////////////////
                        MINT LOGIC
  //////////////////////////////////////////////////////////////*/

  function safeMint(
    address sender_,
    Tier tier,
    Level level
  ) internal returns (uint256) {
    uint256 newTokenId = totalSupply + 1;
    totalSupply++;
    tierConfig[tier].totalSupply++;
    tierConfig[tier].levelConfig[level].totalSupply++;

    _safeMint(sender_, newTokenId);

    tierConfig[tier].levelConfig[level].ownedPerWallet[msg.sender] += 1;

    travelerInfo[newTokenId].tier = tier;
    travelerInfo[newTokenId].level = level;
    travelerInfo[newTokenId].owner = sender_;

    emit TravelersEvent(
      address(0),
      sender_,
      ActionType.Mint,
      newTokenId,
      travelerInfo[newTokenId].tier,
      travelerInfo[newTokenId].level,
      block.number
    );

    return newTokenId;
  }

  function mintWithDiscount(
    string memory uuid,
    Tier tier,
    Level level,
    uint256 discount,
    uint256 nonce,
    Coupon memory coupon
  ) external payable ensurePhase(tier, level) ensureLevel(tier, level) {
    validateDiscount(uuid, tier, level, discount, nonce, coupon);

    require(
      (tierConfig[tier].levelConfig[level].price * (100 - discount)) / 100 ==
        msg.value,
      "WRONG_AMOUNT_PAYED"
    );

    nonces[msg.sender].discount++;
    safeMint(msg.sender, tier, level);

    withdraw();
  }

  function invalidatePrevCoupons(
    string memory uuid,
    Tier tier,
    Level level,
    uint256 discount,
    uint256 nonce,
    Coupon memory coupon
  ) external {
    validateDiscount(uuid, tier, level, discount, nonce, coupon);

    nonces[msg.sender].discount++;
    emit TravelersEvent(
      address(0),
      msg.sender,
      ActionType.Invalidate,
      0,
      tier,
      level,
      block.number
    );
  }

  function mintFromPublicSale(
    Tier tier,
    Level level
  )
    external
    payable
    ensurePhase(tier, level)
    ensureLevel(tier, level)
    ensureAvailabilityFor(tier, level)
    ensureMaxPerWallet(tier, level)
    validateEthPayment(tier, level)
  {
    safeMint(msg.sender, tier, level);

    withdraw();
  }

  function mintFromPreSale(
    uint256 allotted,
    Coupon memory coupon
  )
    external
    payable
    ensurePhase(Tier.Traveler, Level.Genesis)
    ensureAvailabilityFor(Tier.Traveler, Level.Genesis)
    validateEthPayment(Tier.Traveler, Level.Genesis)
  {
    require(1 + addressToPreSaleMints[msg.sender] <= allotted, "MAX_REACHED");

    bytes32 digest = keccak256(
      abi.encode(CouponType.PreSale, allotted, msg.sender)
    );
    require(_isVerifiedCoupon(digest, coupon), "INVALID_COUPON");

    addressToPreSaleMints[msg.sender]++;
    safeMint(msg.sender, Tier.Traveler, Level.Genesis);

    withdraw();
  }

  function mintFromBreedSale(
    Coupon memory coupon,
    uint256 price,
    address payable parent1,
    address payable parent2,
    uint256 parent1Percentage,
    uint256 parent2Percentage
  ) external payable {
    require(price == msg.value, "WRONG_AMOUNT_PAYED");
    bytes32 digest = keccak256(
      abi.encode(
        CouponType.BreedSale,
        price,
        parent1,
        parent2,
        parent1Percentage,
        parent2Percentage
      )
    );
    require(_isVerifiedCoupon(digest, coupon), "INVALID_COUPON");

    uint256 basePrice = tierConfig[Tier.Breed]
      .levelConfig[Level.Platinum]
      .price;
    uint256 parent1Cut = (basePrice * parent1Percentage) / 100;
    uint256 parent2Cut = (basePrice * parent2Percentage) / 100;
    uint256 teamCut = (basePrice * breedFee) / 100;

    uint256 newTokenId = safeMint(msg.sender, Tier.Breed, Level.Platinum);

    parent1.transfer(parent1Cut);
    parent2.transfer(parent2Cut);
    _owner.transfer(teamCut);

    emit Breeded(
      msg.sender,
      newTokenId,
      basePrice,
      parent1,
      parent2,
      parent1Percentage,
      parent2Percentage
    );
  }

  function upgradeTier(
    uint256 tokenId,
    uint256 nonce,
    Tier nextTier,
    Level nextLevel,
    Coupon memory coupon
  ) external {
    require(nonce == nonces[msg.sender].upgrade, "COUPON_USED");
    bytes32 digest = keccak256(
      abi.encode(
        CouponType.Upgrade,
        tokenId,
        nonce,
        nextTier,
        nextLevel,
        msg.sender
      )
    );
    require(_isVerifiedCoupon(digest, coupon), "INVALID_COUPON");
    nonces[msg.sender].upgrade++;

    tierConfig[travelerInfo[tokenId].tier]
      .levelConfig[travelerInfo[tokenId].level]
      .ownedPerWallet[msg.sender]--;

    travelerInfo[tokenId].tier = nextTier;
    travelerInfo[tokenId].level = nextLevel;

    tierConfig[nextTier].levelConfig[nextLevel].ownedPerWallet[msg.sender]++;
  }

  /*//////////////////////////////////////////////////////////////
                          OVERRIDES
  //////////////////////////////////////////////////////////////*/

  function _transfer(
    address from,
    address to,
    uint256 tokenId
  ) internal virtual override(ERC721Upgradeable) {
    require(from == address(0), "FORBIDDEN_ACTION");
    ERC721Upgradeable._transfer(from, to, tokenId);
    travelerInfo[tokenId].owner = to;

    emit TravelersEvent(
      from,
      to,
      ActionType.Transfer,
      tokenId,
      travelerInfo[tokenId].tier,
      travelerInfo[tokenId].level,
      block.number
    );
  }

  /*//////////////////////////////////////////////////////////////
                        ADMIN LOGIC
  //////////////////////////////////////////////////////////////*/

  function setPhaseGlobally(SalePhase phase_) external onlyOwner {
    // Traveler
    setPhasePerTierAndLevel(phase_, Tier.Traveler, Level.Platinum);
    setPhasePerTierAndLevel(phase_, Tier.Traveler, Level.Genesis);
    // Trainer
    setPhasePerTierAndLevel(phase_, Tier.Trainer, Level.Newbie);
    setPhasePerTierAndLevel(phase_, Tier.Trainer, Level.Starter);
    setPhasePerTierAndLevel(phase_, Tier.Trainer, Level.Medium);
    setPhasePerTierAndLevel(phase_, Tier.Trainer, Level.Advanced);
    // Breed
    setPhasePerTierAndLevel(phase_, Tier.Breed, Level.Platinum);
  }

  function setPhasePerTierAndLevel(
    SalePhase phase_,
    Tier tier,
    Level level
  ) public ensureLevel(tier, level) onlyOwner {
    tierConfig[tier].levelConfig[level].phase = phase_;
  }

  function setBaseTokenUri(string calldata baseTokenUri_) external onlyOwner {
    baseTokenUri = baseTokenUri_;
  }

  function setMaxSupplyPerTier(
    uint256 maxSupply_,
    Tier tier
  ) external onlyOwner {
    tierConfig[tier].maxSupply = maxSupply_;
  }

  function setMaxSupplyPerLevel(
    Tier tier,
    Level level,
    uint256 maxSupply_
  ) external onlyOwner {
    tierConfig[tier].levelConfig[level].maxSupply = maxSupply_;
  }

  function setMaxPerWallet(
    Tier tier,
    Level level,
    uint256 maxPerWallet
  ) external onlyOwner {
    tierConfig[tier].levelConfig[level].maxPerWallet = maxPerWallet;
  }

  function setPrice(
    uint256 price,
    Tier tier,
    Level level
  ) external ensureLevel(tier, level) onlyOwner {
    tierConfig[tier].levelConfig[level].price = price;
  }

  function setAdminSigner(address adminSigner_) external onlyOwner {
    _adminSigner = adminSigner_;
  }

  function setBreedFee(uint256 breedFee_) external onlyOwner {
    breedFee = breedFee_;
  }

  function setRewardFee(uint256 rewardFee_) external onlyOwner {
    require(rewardFee_ <= 100 && rewardFee_ >= 0, "FEE_OUT_OF_RANGE");
    rewardFee = rewardFee_;
  }

  function setTierAndLevel(
    uint256 tokenId,
    Tier tier,
    Level level
  ) external ensureLevel(tier, level) onlyOwner {
    travelerInfo[tokenId].tier = tier;
    travelerInfo[tokenId].level = level;
  }

  function withdraw() internal {
    uint256 balance = address(this).balance;

    uint256 teamPercentage = 100 - rewardFee;

    _owner.transfer((balance * teamPercentage) / 100);
    _rewards.transfer((balance * rewardFee) / 100);
  }

  function getPrice(Tier tier, Level level) public view returns (uint256) {
    return tierConfig[tier].levelConfig[level].price;
  }

  function getMaxSupply(Tier tier, Level level) public view returns (uint256) {
    return
      tierConfig[tier].maxSupply == 0
        ? tierConfig[tier].levelConfig[level].maxSupply
        : tierConfig[tier].maxSupply;
  }

  function getPhase(Tier tier, Level level) public view returns (SalePhase) {
    return tierConfig[tier].levelConfig[level].phase;
  }

  function getTotalSupply(
    Tier tier,
    Level level
  ) public view returns (uint256) {
    return
      tier == Tier.Trainer
        ? tierConfig[tier].levelConfig[level].totalSupply
        : tierConfig[tier].totalSupply;
  }

  function getTotalSupplyPerTier(Tier tier) public view returns (uint256) {
    return tierConfig[tier].totalSupply;
  }

  function getTotalSupplyPerLevel(
    Tier tier,
    Level level
  ) public view returns (uint256) {
    return tierConfig[tier].levelConfig[level].totalSupply;
  }

  function getMaxPerWallet(
    Tier tier,
    Level level
  ) public view returns (uint256) {
    return tierConfig[tier].levelConfig[level].maxPerWallet;
  }

  function getOwnedPerWallet(
    Tier tier,
    Level level,
    address target
  ) public view returns (uint256) {
    return tierConfig[tier].levelConfig[level].ownedPerWallet[target];
  }
}