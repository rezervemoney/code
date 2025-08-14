// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Import necessary interfaces and contracts
import "../../core/AppAccessControlled.sol";
import "../../interfaces/IAppTreasury.sol";
import "../../interfaces/IBridgeL1.sol";
import "../../interfaces/IBridgeL2.sol";
import "../../interfaces/ITotalReservesOracle.sol";
import "../../interfaces/ITotalSupplyOracle.sol";
import "../../interfaces/IStaking4626.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import "@layerzerolabs/lz-evm-protocol-v2/contracts/libs/AddressCast.sol";
import "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import "@layerzerolabs/oapp-evm/contracts/oapp/libs/ReadCodecV1.sol";
import "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import "@layerzerolabs/oapp-evm/contracts/oapp/OAppRead.sol";

contract BridgeL1 is AppAccessControlled, OAppRead, OAppOptionsType3, IBridgeL1 {
    uint32 public immutable MAINNET_EID = 30101;

    /// @inheritdoc IBridgeL1
    uint32 public READ_CHANNEL;

    /// @notice Message type identifier for read operations
    uint16 public constant READ_TYPE = 1;

    /// @inheritdoc IBridgeL1
    mapping(uint32 eid => address bridgeL2Reader) public bridgeL2Readers;

    /// @inheritdoc IBridgeL1
    ITotalReservesOracle public totalReservesOracle;

    /// @inheritdoc IBridgeL1
    IAppTreasury public treasury;

    address public lstrzrOFT;

    IStaking4626 public lstRZR;

    IERC20 public rzr;

    /// @notice Initialize the cross-chain read contract
    /// @dev Sets up LayerZero connectivity and establishes read channel peer relationship
    /// @param _endpoint LayerZero endpoint address on the source chain
    /// @param _readChannel Read channel ID for this contract's operations
    constructor(
        uint32 _readChannel,
        address _endpoint,
        address _authority,
        address _totalReservesOracle,
        address _treasury,
        address _lstrzrOFT,
        address _lstRZR,
        address _rzr
    ) OAppRead(_endpoint, msg.sender) Ownable(msg.sender) {
        READ_CHANNEL = _readChannel;
        _setPeer(READ_CHANNEL, AddressCast.toBytes32(address(this)));
        __AppAccessControlled_init(_authority);
        _transferOwnership(address(0));
        totalReservesOracle = ITotalReservesOracle(_totalReservesOracle);
        treasury = IAppTreasury(_treasury);
        lstrzrOFT = _lstrzrOFT;
        lstRZR = IStaking4626(_lstRZR);
        rzr = IERC20(_rzr);

        rzr.approve(address(lstRZR), type(uint256).max);
    }

    function _checkOwner() internal view virtual override {
        if (!authority.isGovernor(_msgSender())) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /// @inheritdoc IBridgeL1
    function registerBridges(uint32[] calldata _eids, address[] calldata _bridgeL2Readers) external onlyGovernor {
        for (uint256 i = 0; i < _eids.length; i++) {
            bridgeL2Readers[_eids[i]] = _bridgeL2Readers[i];
            emit BridgeRegistered(_eids[i], _bridgeL2Readers[i]);
        }
    }

    /// @inheritdoc OAppRead
    function setReadChannel(uint32 _channelId, bool _active) public virtual override onlyGovernor {
        _setPeer(_channelId, _active ? AddressCast.toBytes32(address(this)) : bytes32(0));
        READ_CHANNEL = _channelId;
    }

    /// @inheritdoc IBridgeL1
    function syncMainnetReserves() external onlyExecutor {
        (uint256 usdReserves, uint256 rzrReserves) = treasury.syncReserves();
        totalReservesOracle.setCrosschainReserves(MAINNET_EID, rzrReserves, usdReserves);
    }

    /// @inheritdoc IBridgeL1
    function syncL2Reserves(uint32 eid, bytes calldata _extraOptions)
        external
        payable
        onlyExecutor
        returns (MessagingReceipt memory)
    {
        return _readData(eid, msg.value, _extraOptions);
    }

    /// @inheritdoc IBridgeL1
    function quoteReadFee(uint32 _eid, bytes calldata _extraOptions) external view returns (MessagingFee memory fee) {
        // Build the same command as readSum and quote its cost
        return _quote(
            READ_CHANNEL,
            _getCmd(_eid, bridgeL2Readers[_eid]),
            combineOptions(READ_CHANNEL, READ_TYPE, _extraOptions),
            false
        );
    }

    /// @inheritdoc IBridgeL1
    function flushRZR() external onlyExecutor {
        uint256 balance = IERC20(address(rzr)).balanceOf(address(this));
        lstRZR.deposit(balance, lstrzrOFT);
    }

    /// @notice Internal function to read data from a single bridge on the target chain
    /// @param eid The LayerZero endpoint ID of the target chain
    /// @return receipt LayerZero messaging receipt containing transaction details
    function _readData(uint32 eid, uint256 fee, bytes calldata _extraOptions)
        internal
        returns (MessagingReceipt memory)
    {
        address bridgeL2Reader = bridgeL2Readers[eid];
        if (bridgeL2Reader == address(0)) revert BridgeNotRegistered(eid);

        // 1. Build the read command specifying target function and parameters
        bytes memory cmd = _getCmd(eid, bridgeL2Reader);

        // 2. Send the read request via LayerZero
        return _lzSend(
            READ_CHANNEL,
            cmd,
            combineOptions(READ_CHANNEL, READ_TYPE, _extraOptions),
            MessagingFee(fee, 0),
            payable(msg.sender)
        );
    }

    /// @notice Internal function to build the LayerZero read command for target function execution
    /// @param _eid The LayerZero endpoint ID of the target chain
    /// @param _targetContractAddress The address of the target contract
    /// @return cmd Encoded read command for LayerZero execution
    function _getCmd(uint32 _eid, address _targetContractAddress) internal view returns (bytes memory) {
        // 1. Build the function call data
        // Encode the target function selector with parameters
        bytes memory callData = abi.encodeWithSelector(IBridgeL2.data.selector);

        // 2. Create the read request structure
        EVMCallRequestV1[] memory readRequests = new EVMCallRequestV1[](1);
        readRequests[0] = EVMCallRequestV1({
            appRequestLabel: 1, // Request identifier for tracking
            targetEid: _eid, // Which chain to read from
            isBlockNum: false, // Use timestamp instead of block number for data freshness
            blockNumOrTimestamp: uint64(block.timestamp), // Read current state
            confirmations: 5, // Wait for block finality before executing
            to: _targetContractAddress, // Target contract address
            callData: callData // The function call to execute
        });

        // 3. Encode the command (no compute logic needed for simple reads)
        return ReadCodecV1.encode(0, readRequests);
    }

    /// @notice Internal function to process the received data from the target chain
    function _lzReceive(
        Origin calldata,
        bytes32, /*_guid*/
        bytes calldata _message,
        address, /*_executor*/
        bytes calldata /*_extraData*/
    ) internal override {
        // 1. Validate response format
        // require(_message.length == 32, "Invalid message length");

        // 2. Decode the returned data (matches target function return type)
        (uint32 eid, uint256 rzrReserves, uint256 usdReserves) = abi.decode(_message, (uint32, uint256, uint256));

        // 3. Process the result (emit event, update state, trigger logic, etc.)
        emit StateReceived(eid, rzrReserves, usdReserves);
        totalReservesOracle.setCrosschainReserves(eid, rzrReserves, usdReserves);
    }
}
