// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IAppReferrals {
    struct ClaimRewardsInput {
        address user;
        uint256 amount;
        bytes32[] proofs;
    }

    // Events
    event ReferralCodeRegistered(address indexed referrer, bytes8 code);
    event ReferralRegistered(address indexed referred, bytes8 indexed referrerCode);
    event RewardsClaimed(address indexed user, uint256 amount, bytes32 root);
    event ReferralStaked(address indexed user, uint256 amount, uint256 declaredValue, bytes8 referralCode);
    event ReferralBondBought(address indexed user, uint256 payout, bytes8 referralCode);
    event ReferralStakedIntoLST(address indexed user, uint256 amount, bytes8 referralCode);
    event MerkleServerSet(address indexed merkleServer);
    event MerkleRootSet(bytes32 indexed merkleRoot);

    // Functions
    /// @notice Initializes the contract
    /// @param _rzr The address of the rzr contract
    /// @param _usdr The address of the usdr contract
    /// @param _bond4626 The address of the bond4626 contract
    /// @param _usdtreasury The address of the usdtreasury contract
    /// @param _appTreasury The address of the app treasury contract
    /// @param _staking The address of the staking contract
    /// @param _staking4626 The address of the staking4626 contract
    /// @param _authority The address of the authority
    /// @param _allowReferralCodeRegistration The flag to allow referral code registration
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
    ) external;

    /// @notice Gets the referral code for a user
    /// @param _user The user to get the referral code for
    /// @return referrerCode The referral code for the user
    function userToReferralCode(address _user) external view returns (bytes8 referrerCode);

    /// @notice Gets the user for a referral code
    /// @param _code The referral code to get the user for
    /// @return user The user for the referral code
    function referralCodeToUser(bytes8 _code) external view returns (address user);

    /// @notice Sets the merkle server
    /// @param _merkleServer The merkle server address
    function setMerkleServer(address _merkleServer) external;

    /// @notice Sets the merkle root for the current week
    /// @param _merkleRoot The merkle root for the week
    function setMerkleRoot(bytes32 _merkleRoot) external;

    /// @notice Claims rewards using a merkle proof
    /// @param inputs The inputs for the rewards to claim
    /// @dev The proofs are the two parts of the merkle proof
    function claimRewards(ClaimRewardsInput[] calldata inputs) external;

    /// @notice Registers a referral code for the caller
    function registerReferralCode(bytes8 code) external;

    /// @notice Registers a referral code for the given referrer
    /// @param _code The referral code to register
    /// @param _referrer The referrer to register the referral code for
    function registerReferralCodeFor(bytes8 _code, address _referrer) external;

    /// @notice Gets all referrals for a referrer
    /// @param referrer The referrer to get referrals for
    /// @return referrals Array of addresses that were referred
    function getReferrals(address referrer) external view returns (address[] memory referrals);

    /// @notice Stakes RZR tokens with a referral code
    /// @param amount The amount of RZR tokens to stake
    /// @param declaredValue The declared value of the stake
    /// @param _referralCode The referral code to use
    /// @param _to The address to stake for
    /// @return tokenId_ The ID of the created stake position NFT
    /// @return taxPaid_ The amount of tax paid
    function stakeWithReferral(uint256 amount, uint256 declaredValue, bytes8 _referralCode, address _to)
        external
        returns (uint256 tokenId_, uint256 taxPaid_);

    /// @notice Stakes RZR tokens with a referral code into the LST
    /// @param amount The amount of RZR tokens to stake
    /// @param _referralCode The referral code to use
    /// @param _to The address to stake for
    /// @return minted The amount of tokens minted
    function stakeIntoLSTWithReferral(uint256 amount, bytes8 _referralCode, address _to)
        external
        returns (uint256 minted);

    /// @notice Buys a bond with a referral code
    /// @param _amount The amount of USDR tokens to buy
    /// @param _referralCode The referral code to use
    /// @param _to The address to buy the bond for
    /// @return payout The amount of RZR tokens received
    function bondWithReferral(
        uint256 _amount,
        bytes8 _referralCode,
        address _to
    ) external returns (uint256 payout);
}
