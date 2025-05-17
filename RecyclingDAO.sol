// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract RecyclingDAO {
    address public owner;

    struct Member {
        bool isMember;
        uint256 successfulVotes; // Track member's successful votes (as a reward metric)
    }
    mapping(address => Member) public members;
    address[] public memberList;

    struct Proposal {
        string description;
        uint256 voteThreshold;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 deadline;
        bool executed;
        mapping(address => bool) hasVoted;
    }
    Proposal[] public proposals;

    event MemberAdded(address member);
    event ProposalCreated(uint256 proposalId, string description);
    event VoteCast(uint256 proposalId, address voter, bool support);
    event ProposalExecuted(uint256 proposalId);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyMember() {
        require(members[msg.sender].isMember, "Not a member");
        _;
    }

    constructor() {
        owner = msg.sender;
        members[msg.sender] = Member(true, 0);
        memberList.push(msg.sender);
    }

    function addMember(address newMember) external onlyOwner {
        require(!members[newMember].isMember, "Already a member");
        members[newMember] = Member(true, 0);
        memberList.push(newMember);
        emit MemberAdded(newMember);
    }

    function createProposal(string calldata description, uint256 voteThreshold, uint256 durationSeconds) external onlyOwner {
        Proposal storage p = proposals.push();
        p.description = description;
        p.voteThreshold = voteThreshold;
        p.deadline = block.timestamp + durationSeconds;
        emit ProposalCreated(proposals.length - 1, description);
    }

    function castVote(uint256 proposalId, bool support) external onlyMember {
        require(proposalId < proposals.length, "Invalid proposal");
        Proposal storage p = proposals[proposalId];
        require(block.timestamp <= p.deadline, "Voting ended");
        require(!p.hasVoted[msg.sender], "Already voted");
        p.hasVoted[msg.sender] = true;
        if (support) {
            p.votesFor += 1;
        } else {
            p.votesAgainst += 1;
        }
        emit VoteCast(proposalId, msg.sender, support);
    }

    function executeProposal(uint256 proposalId) external onlyOwner {
        require(proposalId < proposals.length, "Invalid proposal");
        Proposal storage p = proposals[proposalId];
        require(!p.executed, "Already executed");
        require(block.timestamp > p.deadline, "Voting still ongoing");
        require(p.votesFor >= p.voteThreshold, "Threshold not met");
        p.executed = true;

        // Reward members who voted "for" the successful proposal
        for (uint256 i = 0; i < memberList.length; i++) {
            address member = memberList[i];
            if (p.hasVoted[member]) {
                members[member].successfulVotes += 1;
            }
        }
        emit ProposalExecuted(proposalId);
    }

    // Helper functions for frontend
    function getProposal(uint256 proposalId) external view returns (
        string memory description,
        uint256 voteThreshold,
        uint256 votesFor,
        uint256 votesAgainst,
        uint256 deadline,
        bool executed
    ) {
        Proposal storage p = proposals[proposalId];
        return (
            p.description,
            p.voteThreshold,
            p.votesFor,
            p.votesAgainst,
            p.deadline,
            p.executed
        );
    }

    function getProposalsCount() external view returns (uint256) {
        return proposals.length;
    }

    function getMembers() external view returns (address[] memory) {
        return memberList;
    }

    function getMemberInfo(address member) external view returns (bool isMember, uint256 successfulVotes) {
        Member storage m = members[member];
        return (m.isMember, m.successfulVotes);
    }
}
