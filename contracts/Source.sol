// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./lzApp/NonblockingLzApp.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IStargateRouter.sol";
import "../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";


contract Source is NonblockingLzApp {
    using SafeMath for uint256;

    uint256 constant MAX_INT = 115792089237316195423570985008687907853269984665640564039457584007913129639935;

    IStargateRouter public stargateRouter;
    // Address of Destination contract where all the money will be sent
    address public destination;
    // Chain id of Destination Chain
    uint16 dstChainId;
    // Chain id of Source Chain
    uint256 srcPoolId;
    // Pool id of the Destination Chain
    uint256 dstPoolId;

    constructor(
        address _lzEndpoint,
        address _stargateRouter,
        address _destination,
        uint16 _dstChainId,
        uint256 _srcPoolId,
        uint256 _dstPoolId
    ) NonblockingLzApp(_lzEndpoint) {
        stargateRouter = IStargateRouter(_stargateRouter);
        destination = _destination;
        dstChainId = _dstChainId;
        srcPoolId = _srcPoolId;
        dstPoolId = _dstPoolId;
    }

    /// @param _amount - cost of the NFT
    /// @param _fee - fee for the crosschain message
    /// @param commands - commands (uniswap aggregator function)
    /// @param inputs - inputs (uniswap aggregator function)
    /// @param _nft - NFT address
    function purchase(uint256 _amount, uint256 _fee, bytes calldata commands, bytes[] calldata inputs, address _nft) public payable {
        require(_amount > 0, "need _amount > 0");
        require(msg.value == (_amount + _fee), "stargate requires fee to pay crosschain message");
        
        bytes memory data = abi.encode(msg.sender, commands, inputs, _nft);

        // Stargate's Router.swap() function sends the tokens to the destination chain.
        stargateRouter.swap{value:_fee}(
            dstChainId,                                     // the destination chain id
            srcPoolId,                                      // the source Stargate poolId
            dstPoolId,                                      // the destination Stargate poolId
            payable(msg.sender),                            // refund adddress. if msg.sender pays too much gas, return extra eth
            _amount,                                        // total tokens to send to destination chain
            0,                                              // min amount allowed out
            IStargateRouter.lzTxObj(200000, 0, "0x"),       // default lzTxObj
            abi.encodePacked(destination),                  // destination address 
            data                                            // bytes payload
        );
    }

    function _nonblockingLzReceive(
        uint16 _srcChainId, 
        bytes memory _srcAddress, 
        uint64 _nonce, 
        bytes memory _payload
    ) internal override {

    }
}