// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Decentralized Micro-insurance
 * @dev A smart contract for managing micro-insurance policies with automated claims processing
 */
contract Project {
    // Struct to represent an insurance policy
    struct Policy {
        uint256 id;
        address policyholder;
        uint256 premium;
        uint256 coverageAmount;
        uint256 startTime;
        uint256 duration; // in seconds
        bool isActive;
        bool hasClaimed;
        string policyType; // e.g., "crop", "health", "device"
    }
    
    // Struct to represent a claim
    struct Claim {
        uint256 policyId;
        address claimant;
        uint256 claimAmount;
        string reason;
        bool isApproved;
        bool isPaid;
        uint256 timestamp;
    }
    
    // State variables
    mapping(uint256 => Policy) public policies;
    mapping(uint256 => Claim) public claims;
    mapping(address => uint256[]) public userPolicies;
    
    uint256 public nextPolicyId = 1;
    uint256 public nextClaimId = 1;
    address public owner;
    uint256 public totalPremiumPool;
    
    // Events
    event PolicyCreated(uint256 indexed policyId, address indexed policyholder, uint256 premium, uint256 coverageAmount);
    event ClaimSubmitted(uint256 indexed claimId, uint256 indexed policyId, address indexed claimant, uint256 amount);
    event ClaimProcessed(uint256 indexed claimId, bool approved, uint256 payoutAmount);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlyPolicyholder(uint256 _policyId) {
        require(policies[_policyId].policyholder == msg.sender, "Only policyholder can call this function");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    /**
     * @dev Core Function 1: Purchase Insurance Policy
     * @param _coverageAmount The amount to be covered by the insurance
     * @param _duration Duration of the policy in seconds
     * @param _policyType Type of insurance (crop, health, device, etc.)
     */
    function purchasePolicy(
        uint256 _coverageAmount,
        uint256 _duration,
        string memory _policyType
    ) external payable {
        require(msg.value > 0, "Premium must be greater than 0");
        require(_coverageAmount > 0, "Coverage amount must be greater than 0");
        require(_duration > 0, "Duration must be greater than 0");
        require(msg.value <= _coverageAmount / 10, "Premium cannot exceed 10% of coverage amount");
        
        // Create new policy
        Policy memory newPolicy = Policy({
            id: nextPolicyId,
            policyholder: msg.sender,
            premium: msg.value,
            coverageAmount: _coverageAmount,
            startTime: block.timestamp,
            duration: _duration,
            isActive: true,
            hasClaimed: false,
            policyType: _policyType
        });
        
        policies[nextPolicyId] = newPolicy;
        userPolicies[msg.sender].push(nextPolicyId);
        totalPremiumPool += msg.value;
        
        emit PolicyCreated(nextPolicyId, msg.sender, msg.value, _coverageAmount);
        nextPolicyId++;
    }
    
    /**
     * @dev Core Function 2: Submit Insurance Claim
     * @param _policyId The ID of the policy for which claim is being made
     * @param _claimAmount The amount being claimed
     * @param _reason Reason for the claim
     */
    function submitClaim(
        uint256 _policyId,
        uint256 _claimAmount,
        string memory _reason
    ) external onlyPolicyholder(_policyId) {
        Policy storage policy = policies[_policyId];
        
        require(policy.isActive, "Policy is not active");
        require(!policy.hasClaimed, "Claim already submitted for this policy");
        require(block.timestamp <= policy.startTime + policy.duration, "Policy has expired");
        require(_claimAmount <= policy.coverageAmount, "Claim amount exceeds coverage");
        require(_claimAmount > 0, "Claim amount must be greater than 0");
        
        // Create new claim
        Claim memory newClaim = Claim({
            policyId: _policyId,
            claimant: msg.sender,
            claimAmount: _claimAmount,
            reason: _reason,
            isApproved: false,
            isPaid: false,
            timestamp: block.timestamp
        });
        
        claims[nextClaimId] = newClaim;
        policy.hasClaimed = true;
        
        emit ClaimSubmitted(nextClaimId, _policyId, msg.sender, _claimAmount);
        nextClaimId++;
    }
    
    /**
     * @dev Core Function 3: Process and Pay Claims
     * @param _claimId The ID of the claim to process
     * @param _approve Whether to approve or reject the claim
     */
    function processClaim(uint256 _claimId, bool _approve) external onlyOwner {
        Claim storage claim = claims[_claimId];
        
        require(claim.claimant != address(0), "Claim does not exist");
        require(!claim.isPaid, "Claim already processed");
        
        claim.isApproved = _approve;
        
        if (_approve) {
            require(address(this).balance >= claim.claimAmount, "Insufficient funds in contract");
            
            // Transfer claim amount to claimant
            payable(claim.claimant).transfer(claim.claimAmount);
            claim.isPaid = true;
            
            // Deactivate the policy after successful claim
            policies[claim.policyId].isActive = false;
            
            emit ClaimProcessed(_claimId, true, claim.claimAmount);
        } else {
            // If claim is rejected, reactivate the policy's claim status
            policies[claim.policyId].hasClaimed = false;
            emit ClaimProcessed(_claimId, false, 0);
        }
    }
    
    // Additional utility functions
    
    /**
     * @dev Get policy details
     */
    function getPolicyDetails(uint256 _policyId) external view returns (Policy memory) {
        return policies[_policyId];
    }
    
    /**
     * @dev Get claim details
     */
    function getClaimDetails(uint256 _claimId) external view returns (Claim memory) {
        return claims[_claimId];
    }
    
    /**
     * @dev Get user's policies
     */
    function getUserPolicies(address _user) external view returns (uint256[] memory) {
        return userPolicies[_user];
    }
    
    /**
     * @dev Check if policy is still valid
     */
    function isPolicyValid(uint256 _policyId) external view returns (bool) {
        Policy memory policy = policies[_policyId];
        return policy.isActive && (block.timestamp <= policy.startTime + policy.duration);
    }
    
    /**
     * @dev Get contract balance
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * @dev Emergency withdrawal function (only owner)
     */
    function emergencyWithdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
    
    /**
     * @dev Transfer ownership
     */
    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "New owner cannot be zero address");
        owner = _newOwner;
    }
}
