// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./lzApp/NonblockingLzApp.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IStargateRouter.sol";
import "../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IUniversalRouter.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./interfaces/IStargateEthVault.sol";

contract Destination is NonblockingLzApp {
    IStargateRouter public stargateRouter;
    IUniversalRouter public universalRouter;
    IStargateEthVault public stargateEthVault;

    /// @param _lzEndpoint - LayerZero Endpoint
    /// @param _stargateRouter - Stargate Router
    /// @param _universalRouter - Universal Router (A.K.A Uniswap NFT Aggregator)
    /// @param _stargateEthVault - Stargate Eth Vault
    constructor(
        address _lzEndpoint,
        address _stargateRouter,
        address _universalRouter,
        address _stargateEthVault
    ) NonblockingLzApp(_lzEndpoint) {
        require(_stargateEthVault != address(0x0), "RouterETH: _stargateEthVault cant be 0x0");
        require(_stargateRouter != address(0x0), "RouterETH: _stargateRouter cant be 0x0");

        stargateRouter = IStargateRouter(_stargateRouter);
        universalRouter = IUniversalRouter(_universalRouter);
        stargateEthVault = IStargateEthVault(_stargateEthVault);
    }

    function executeTrade(
        address sender,
        bytes calldata commands, 
        bytes[] calldata inputs, 
        address _nft,
        uint256 _tokenId
    ) public payable {
        try universalRouter.execute{value: _amountLD}(commands, inputs, block.timestamp) {
            // Transfer NFT to sender
            IERC721(_nft).safeTransferFrom(address(this), sender, _tokenId);
        } catch {
            payable(sender).transfer(_amountLD);
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
    ) external {
        require(msg.sender == address(stargateRouter), "Unauthorized");
        require(_amountLD > 0, "_amount must be greater than 0");

        (
            address sender, 
            bytes memory commands, 
            bytes[] memory inputs,
            address _nft,
            uint256 _tokenId
        ) = abi.decode(_payload, (address, bytes, bytes[], address, uint256));

        // Unwrap & Approve ETH
        stargateEthVault.approve(address(stargateEthVault), _amountLD);
        stargateEthVault.withdraw(_amountLD);

        this.executeTrade(sender, commands, inputs, _nft, _tokenId);
    }    

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
