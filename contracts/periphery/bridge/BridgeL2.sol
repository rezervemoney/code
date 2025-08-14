// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.28;

import "../../interfaces/IBridgeL2.sol";
import "../../interfaces/IStaking4626L2.sol";
import "../../interfaces/IAppTreasury.sol";
import "../../core/AppAccessControlled.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import "@layerzerolabs/lz-evm-protocol-v2/contracts/libs/AddressCast.sol";
import "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import "@layerzerolabs/oapp-evm/contracts/oapp/libs/ReadCodecV1.sol";
import "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import "@layerzerolabs/oapp-evm/contracts/oapp/OAppRead.sol";
import "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";

contract BridgeL2 is AppAccessControlled, OAppRead, OAppOptionsType3, IBridgeL2 {
    /// @inheritdoc IBridgeL2
    uint32 public READ_CHANNEL;

    /// @notice Message type identifier for read operations
    uint16 public constant READ_TYPE = 1;

    /// @inheritdoc IBridgeL2
    address public immutable LIQUID_STAKING_MAINNET = 0xB33f4B9C6f0624EdeAE8881c97381837760D52CB;

    address public immutable BRIDGE_MAINNET = 0x507427Db12766d70445C85e683eFD30143Bf99DF;

    /// @inheritdoc IBridgeL2
    uint32 public immutable MAINNET_EID = 30101;

    uint32 public immutable eid;
    IStaking4626L2 public liquidStaking;
    IAppTreasury public treasury;

    IOFT public immutable rzr;

    /// @notice Initialize the contract
    /// @param _eid The EID of the L2 chain
    /// @param _authority The address of the authority
    /// @param _liquidStaking The address of the liquid staking
    /// @param _treasury The address of the treasury
    /// @param _endpoint The endpoint to use
    /// @param _readChannel The read channel to use
    constructor(
        uint32 _eid,
        uint32 _readChannel,
        address _endpoint,
        address _authority,
        address _liquidStaking,
        address _treasury,
        address _rzr
    ) OAppRead(_endpoint, msg.sender) Ownable(msg.sender) {
        _setPeer(READ_CHANNEL, AddressCast.toBytes32(address(this)));
        __AppAccessControlled_init(_authority);
        _transferOwnership(address(0));
        eid = _eid;
        READ_CHANNEL = _readChannel;
        liquidStaking = IStaking4626L2(_liquidStaking);
        treasury = IAppTreasury(_treasury);
        rzr = IOFT(_rzr);
    }

    receive() external payable {}

    function _checkOwner() internal view virtual override {
        if (!authority.isGovernor(_msgSender())) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    function flushToL1() external payable onlyExecutor {
        uint256 balance = IERC20(address(rzr)).balanceOf(address(this));
        rzr.send{value: msg.value}(
            SendParam({
                dstEid: MAINNET_EID,
                to: bytes32(uint256(uint160(BRIDGE_MAINNET))),
                amountLD: balance,
                minAmountLD: balance,
                extraOptions: "",
                composeMsg: "",
                oftCmd: ""
            }),
            MessagingFee({nativeFee: msg.value, lzTokenFee: 0}),
            address(this)
        );
    }

    /// @inheritdoc OAppRead
    function setReadChannel(uint32 _channelId, bool _active) public virtual override onlyGovernor {
        _setPeer(_channelId, _active ? AddressCast.toBytes32(address(this)) : bytes32(0));
        READ_CHANNEL = _channelId;
    }

    /// @inheritdoc IBridgeL2
    function syncRate(bytes calldata _extraOptions) external payable onlyExecutor returns (MessagingReceipt memory) {
        return _readData(msg.value, _extraOptions);
    }

    /// @inheritdoc IBridgeL2
    function quoteReadFee(bytes calldata _extraOptions) external view returns (MessagingFee memory fee) {
        // Build the same command as readSum and quote its cost
        return _quote(READ_CHANNEL, _getCmd(), combineOptions(READ_CHANNEL, READ_TYPE, _extraOptions), false);
    }

    /// @notice Internal function to build the LayerZero read command for target function execution
    /// @return cmd Encoded read command for LayerZero execution
    function _getCmd() internal view returns (bytes memory) {
        // 1. Build the function call data
        // Encode the target function selector with parameters
        bytes memory callData = abi.encodeWithSelector(IStaking4626L2.rate.selector);

        // 2. Create the read request structure
        EVMCallRequestV1[] memory readRequests = new EVMCallRequestV1[](1);
        readRequests[0] = EVMCallRequestV1({
            appRequestLabel: 1, // Request identifier for tracking
            targetEid: MAINNET_EID, // Which chain to read from
            isBlockNum: false, // Use timestamp instead of block number for data freshness
            blockNumOrTimestamp: uint64(block.timestamp), // Read current state
            confirmations: 5, // Wait for block finality before executing
            to: LIQUID_STAKING_MAINNET, // Target contract address
            callData: callData // The function call to execute
        });

        // 3. Encode the command (no compute logic needed for simple reads)
        return ReadCodecV1.encode(0, readRequests);
    }

    /// @notice Internal function to read data from a single bridge on the target chain
    /// @param fee The fee to pay for the read
    /// @param _extraOptions Extra options for the read
    /// @return receipt LayerZero messaging receipt containing transaction details
    function _readData(uint256 fee, bytes calldata _extraOptions) internal returns (MessagingReceipt memory) {
        // 1. Build the read command specifying target function and parameters
        bytes memory cmd = _getCmd();

        // 2. Send the read request via LayerZero
        return _lzSend(
            READ_CHANNEL,
            cmd,
            combineOptions(READ_CHANNEL, READ_TYPE, _extraOptions),
            MessagingFee(fee, 0),
            payable(msg.sender)
        );
    }

    /// @inheritdoc IBridgeL2
    function data() public view returns (uint32 _eid, uint256 _rzrReserves, uint256 _usdReserves) {
        _eid = eid;
        (_usdReserves, _rzrReserves) = treasury.calculateReserves();
    }

    /// @notice Internal function to process the received data from the target chain
    function _lzReceive(
        Origin calldata,
        bytes32, /*_guid*/
        bytes calldata _message,
        address, /*_executor*/
        bytes calldata /*_extraData*/
    ) internal override {
        (uint256 rate) = abi.decode(_message, (uint256));
        liquidStaking.setRate(rate);
    }
}
