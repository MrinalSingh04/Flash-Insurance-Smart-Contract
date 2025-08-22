// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @dev Instant short-term insurance (e.g. flight delay, rain coverage).
 * Premium is paid upfront; payout occurs if insured event is triggered within coverage window.
 */

contract FlashInsurance {
    struct Policy {
        address insured;
        uint256 premiumPaid;
        uint256 payoutAmount;
        uint256 startTime;
        uint256 endTime;
        bool active;
        bool claimed;
    }

    uint256 public policyCounter;
    address public insurer; // contract owner
    mapping(uint256 => Policy) public policies;

    event PolicyPurchased(
        uint256 indexed policyId,
        address indexed user,
        uint256 startTime,
        uint256 endTime
    );
    event PolicyClaimed(
        uint256 indexed policyId,
        address indexed user,
        uint256 payout
    );
    event PolicyExpired(uint256 indexed policyId);

    modifier onlyInsurer() {
        require(msg.sender == insurer, "Only insurer can call");
        _;
    }

    constructor() {
        insurer = msg.sender;
    }

    /**
     * @dev Purchase a short-term insurance policy
     * @param coverageDuration duration in seconds
     */
    function purchasePolicy(uint256 coverageDuration) external payable {
        require(msg.value > 0, "Premium must be > 0");
        require(coverageDuration > 0, "Duration must be > 0");

        uint256 policyId = ++policyCounter;

        // payout is 2x premium (example logic, can be changed)
        uint256 payout = msg.value * 2;

        policies[policyId] = Policy({
            insured: msg.sender,
            premiumPaid: msg.value,
            payoutAmount: payout,
            startTime: block.timestamp,
            endTime: block.timestamp + coverageDuration,
            active: true,
            claimed: false
        });

        emit PolicyPurchased(
            policyId,
            msg.sender,
            block.timestamp,
            block.timestamp + coverageDuration
        );
    }

    /**
     * @dev Trigger event outcome (oracle or insurer sets this)
     * In production: integrate Chainlink or another oracle
     */
    function claimPolicy(
        uint256 policyId,
        bool eventOccurred
    ) external onlyInsurer {
        Policy storage policy = policies[policyId];
        require(policy.active, "Policy inactive");
        require(!policy.claimed, "Already claimed");
        require(block.timestamp <= policy.endTime, "Policy expired");

        if (eventOccurred) {
            policy.claimed = true;
            policy.active = false;
            payable(policy.insured).transfer(policy.payoutAmount);
            emit PolicyClaimed(policyId, policy.insured, policy.payoutAmount);
        } else {
            // If no event, insurance expires worthless
            policy.active = false;
            emit PolicyExpired(policyId);
        }
    }

    /**
     * @dev Withdraw insurer funds (collected premiums)
     */
    function withdraw(uint256 amount) external onlyInsurer {
        require(amount <= address(this).balance, "Not enough balance");
        payable(insurer).transfer(amount);
    }

    // Fallback to accept ETH
    receive() external payable {}
}
