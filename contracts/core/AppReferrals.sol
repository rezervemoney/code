// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "../interfaces/IApp.sol";
import "../interfaces/IUSDTreasury.sol";
import "../interfaces/IAppOracle.sol";
import "../interfaces/IAppReferrals.sol";
import "../interfaces/IAppStaking.sol";
import "../interfaces/IAppTreasury.sol";
import "../interfaces/IStaking4626.sol";
import "./AppAccessControlled.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/// @title AppReferrals
/// @notice This contract is used to track referrals and rewards
/// @dev Reward calculations are done off-chain in future yields
contract AppReferrals is AppAccessControlled, ReentrancyGuardUpgradeable, IAppReferrals {
    using SafeERC20 for IERC20;
    using SafeERC20 for IApp;
    using SafeERC20 for IERC4626;
    using EnumerableSet for EnumerableSet.AddressSet;
    using MerkleProof for bytes32[];

    // State variables
    IAppStaking public staking;
    IApp public rzr;
    IApp public usdr;
    IERC4626 public bond4626;
    IUSDTreasury public usdtreasury;
    IAppTreasury public appTreasury;
    IStaking4626 public staking4626;

    bytes32 public merkleRoot;

    // Track claimed rewards
    mapping(address user => uint256 claimed) public claimedRewards; // user => claimed

    // Referral tracking
    mapping(address user => bytes8 referralCode) public trackedReferrals;
    mapping(bytes8 referrerCode => EnumerableSet.AddressSet referrals) private _referrals;

    mapping(address user => bytes8 code) public userToReferralCode;
    mapping(bytes8 code => address user) public referralCodeToUser;

    address public merkleServer;
    uint256 public totalClaimed;

    bool public allowReferralCodeRegistration;

    /// @inheritdoc IAppReferrals
    function initialize(
        address _rzr,
        address _usdr,
        address _bond4626,
        address _usdtreasury,
        address _appTreasury,
        address _staking,
        address _staking4626,
        address _authority,
        bool _allowReferralCodeRegistration
    ) external reinitializer(4) {
        __AppAccessControlled_init(_authority);
        __ReentrancyGuard_init();

        rzr = IApp(_rzr);
        usdr = IApp(_usdr);
        bond4626 = IERC4626(_bond4626);
        usdtreasury = IUSDTreasury(_usdtreasury);
        appTreasury = IAppTreasury(_appTreasury);
        staking = IAppStaking(_staking);
        staking4626 = IStaking4626(_staking4626);
        rzr.approve(address(staking4626), type(uint256).max);

        allowReferralCodeRegistration = _allowReferralCodeRegistration;

        if (address(staking) != address(0)) rzr.approve(address(staking), type(uint256).max);
        if (address(usdr) != address(0)) usdr.approve(address(bond4626), type(uint256).max);
    }

    /// @inheritdoc IAppReferrals
    function setMerkleServer(address _merkleServer) external onlyGovernor {
        merkleServer = _merkleServer;
        emit MerkleServerSet(_merkleServer);
    }

    /// @inheritdoc IAppReferrals
    function setMerkleRoot(bytes32 _merkleRoot) external {
        require(msg.sender == merkleServer, "Only merkle server can set merkle root");
        merkleRoot = _merkleRoot;
        emit MerkleRootSet(_merkleRoot);
    }

    /// @inheritdoc IAppReferrals
    function claimRewards(ClaimRewardsInput[] calldata inputs) external {
        for (uint256 i = 0; i < inputs.length; i++) {
            _claimRewards(inputs[i]);
        }
    }

    /// @inheritdoc IAppReferrals
    function registerReferralCode(bytes8 _code) external {
        _registerReferralCode(_code, msg.sender);
    }

    /// @inheritdoc IAppReferrals
    function registerReferralCodeFor(bytes8 _code, address _referrer) external onlyExecutor {
        _registerReferralCode(_code, _referrer);
    }


    /// @notice Gets the total number of referrals made by a referrer
    /// @param _referrer The referrer to get the total number of referrals for
    /// @return The total number of referrals made by the referrer
    function totalReferralsMade(address _referrer) external view returns (uint256) {
        return _referrals[userToReferralCode[_referrer]].length();
    }

    /// @inheritdoc IAppReferrals
    function getReferrals(address _referrer) external view returns (address[] memory referrals) {
        EnumerableSet.AddressSet storage refs = _referrals[userToReferralCode[_referrer]];
        referrals = new address[](refs.length());
        for (uint256 i = 0; i < refs.length(); i++) referrals[i] = refs.at(i);
    }

    /// @inheritdoc IAppReferrals
    function stakeWithReferral(uint256 amount, uint256 declaredValue, bytes8 _referralCode, address _to)
        external
        nonReentrant
        returns (uint256 tokenId, uint256 taxPaid)
    {
        rzr.safeTransferFrom(msg.sender, address(this), amount);

        // pay out any referral rewards if a referral code was set
        bytes8 _registeredReferralCode = _registerReferral(_referralCode, _to);

        // stake on behalf of the referrer
        (tokenId, taxPaid) = staking.createPosition(_to, amount, declaredValue, 0);

        emit ReferralStaked(_to, amount, declaredValue, _registeredReferralCode);
    }


    /// @inheritdoc IAppReferrals
    function stakeIntoLSTWithReferral(uint256 amount, bytes8 _referralCode, address _to)
        external
        nonReentrant
        returns (uint256 minted)
    {
        rzr.safeTransferFrom(msg.sender, address(this), amount);
        bytes8 _registeredReferralCode = _registerReferral(_referralCode, _to);
        minted = staking4626.deposit(amount, _to);
        emit ReferralStakedIntoLST(_to, amount, _registeredReferralCode);
    }

    /// @inheritdoc IAppReferrals
    function bondWithReferral(
        uint256 _amount,
        bytes8 _referralCode,
        address _to
    ) external nonReentrant returns (uint256 payout) {
        // register referral if not already registered for tracking purposes only
        bytes8 _registeredReferralCode = _registerReferral(_referralCode, _to);

        // mint bond on behalf of the referrer
        usdr.safeTransferFrom(msg.sender, address(this), _amount);
        payout = bond4626.deposit(_amount, _to);

        emit ReferralBondBought(_to, payout, _registeredReferralCode);
    }

    /// @dev Registers a referral for the given user
    /// @param _code The referral code to use
    /// @param _user The user to register the referral for
    function _registerReferral(bytes8 _code, address _user) internal returns (bytes8 _registeredReferralCode) {
        // if the user is already tracked by someone, we skip and return the referrer's code
        if (trackedReferrals[_user] != bytes8(0)) return trackedReferrals[_user];

        // track the referral regardless of whether the code is registered
        trackedReferrals[_user] = _code;
        if (!_referrals[_code].contains(_user)) _referrals[_code].add(_user);

        emit ReferralRegistered(_user, _code);
        return _code;
    }

    /// @dev Registers a referral code for the given referrer
    /// @param _referralCode The referral code to register
    /// @param _referrer The referrer to register the referral code for
    function _registerReferralCode(bytes8 _referralCode, address _referrer) internal {
        require(allowReferralCodeRegistration, "Referral code registration is not allowed");
        require(referralCodeToUser[_referralCode] == address(0), "Code already exists");
        require(userToReferralCode[_referrer] == bytes8(0), "Referral code already registered");
        require(_referralCode != bytes8(0), "Invalid code");

        referralCodeToUser[_referralCode] = _referrer;
        userToReferralCode[_referrer] = _referralCode;

        emit ReferralCodeRegistered(_referrer, _referralCode);
    }

    /// @dev Claims rewards for the given input
    /// @param input The input to claim rewards for
    function _claimRewards(ClaimRewardsInput calldata input) internal nonReentrant {
        // Create the leaf node
        bytes32 leaf = keccak256(abi.encodePacked(input.user, input.amount));

        // Verify the proof
        require(input.proofs.verify(merkleRoot, leaf), "Invalid proof");

        // Check if already claimed
        uint256 claimable = input.amount - claimedRewards[input.user];
        require(claimable > 0, "No rewards to claim");
        claimedRewards[input.user] += claimable;
        totalClaimed += claimable;

        // Transfer rewards
        rzr.safeTransfer(input.user, claimable);

        emit RewardsClaimed(input.user, input.amount, merkleRoot);
    }
}
