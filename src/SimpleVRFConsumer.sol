// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol";
import "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import "lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import "lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

contract SimpleVRFConsumer is VRFV2PlusWrapperConsumerBase, ConfirmedOwner {
    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords, uint256 payment);

    struct RequestStatus {
        uint256 paid;
        bool fulfilled;
        uint256[] randomWords;
    }

    mapping(uint256 => RequestStatus) public s_requests;
    uint256[] public requestIds;
    uint256 public lastRequestId;

    uint32 public callbackGasLimit = 100000;
    uint16 public requestConfirmations = 3;
    uint32 public numWords = 2;

    address public linkAddress = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
    address public wrapperAddress = 0x02aae1A04f9828517b3007f83f6181900CaD910c;

    constructor() ConfirmedOwner(msg.sender) VRFV2PlusWrapperConsumerBase(wrapperAddress) {}

    function requestRandomWords(bool enableNativePayment) external onlyOwner returns (uint256) {
        bytes memory extraArgs = VRFV2PlusClient._argsToBytes(
            VRFV2PlusClient.ExtraArgsV1({nativePayment: enableNativePayment})
        );

        uint256 requestId;
        uint256 reqPrice;

        if (enableNativePayment) {
            (requestId, reqPrice) = requestRandomnessPayInNative(
                callbackGasLimit,
                requestConfirmations,
                numWords,
                extraArgs
            );
        } else {
            (requestId, reqPrice) = requestRandomness(
                callbackGasLimit,
                requestConfirmations,
                numWords,
                extraArgs
            );
        }

        s_requests[requestId] = RequestStatus({
            paid: reqPrice,
            randomWords: new uint256[](0),
            fulfilled: false
        });

        requestIds.push(requestId);
        lastRequestId = requestId;

        emit RequestSent(requestId, numWords);
        return requestId;
    }

    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
        require(s_requests[_requestId].paid > 0, "request not found");
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;
        emit RequestFulfilled(_requestId, _randomWords, s_requests[_requestId].paid);
    }

    function getRequestStatus(uint256 _requestId) external view returns (uint256 paid, bool fulfilled, uint256[] memory randomWords) {
        require(s_requests[_requestId].paid > 0, "request not found");
        RequestStatus memory request = s_requests[_requestId];
        return (request.paid, request.fulfilled, request.randomWords);
    }

    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(linkAddress);
        require(link.transfer(msg.sender, link.balanceOf(address(this))), "Unable to transfer");
    }

    function withdrawNative(uint256 amount) external onlyOwner {
        (bool success, ) = payable(owner()).call{value: amount}("");
        require(success, "withdrawNative failed");
    }

    receive() external payable {
        // Allow contract to receive ETH
    }
}
