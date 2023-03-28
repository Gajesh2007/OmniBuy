// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./lzApp/NonblockingLzApp.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IStargateRouter.sol";
import "../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IUniversalRouter.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract Destination is NonblockingLzApp {
    IStargateRouter public stargateRouter;
    IUniversalRouter public universalRouter;

    /// @param _lzEndpoint - LayerZero Endpoint
    /// @param _stargateRouter - Stargate Router
    /// @param _universalRouter - Universal Router (A.K.A Uniswap NFT Aggregator)
    constructor(
        address _lzEndpoint,
        address _stargateRouter,
        address _universalRouter 
    ) NonblockingLzApp(_lzEndpoint) {
        stargateRouter = IStargateRouter(_stargateRouter);
        universalRouter = IUniversalRouter(_universalRouter);
    }

    function executeTrade(
        address sender,
        bytes calldata commands, 
        bytes[] calldata inputs, 
        address _nft
    ) public payable {
        try universalRouter.execute{value: msg.value}(commands, inputs, block.timestamp) {
            // Transfer NFT to sender
            IERC721(_nft).safeTransferFrom(address(this), sender, 0);
        } catch {
            payable(sender).transfer(msg.value);
        }
    }

    function _nonblockingLzReceive(
        uint16 _srcChainId, 
        bytes memory _srcAddress, 
        uint64 _nonce, 
        bytes memory _payload
    ) internal override {

    }

    function sgReceive(
        uint16 _chainId, 
        bytes memory _srcAddress, 
        uint _nonce, 
        address _token, 
        uint amountLD, 
        bytes memory _payload
    ) external payable {
        require(msg.sender == address(stargateRouter), "Unauthorized");
        require(msg.value > 0, "msg.value must be greater than 0");

        (
            address sender, 
            bytes memory commands, 
            bytes[] memory inputs, 
            address _nft
        ) = abi.decode(_payload, (address, bytes, bytes[], address));

        this.executeTrade(sender, commands, inputs, _nft);
    }    
}