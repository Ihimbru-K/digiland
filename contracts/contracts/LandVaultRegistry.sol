// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract LandVaultRegistry {
    address public owner;

    struct PlotRecord {
        bytes32 documentHash;
        uint256 timestamp;
        address registeredBy;
        bool    exists;
    }

    mapping(string => PlotRecord) private records;
    mapping(address => bool) public authorizedAgents;

    constructor() {
        owner = msg.sender;
        authorizedAgents[msg.sender] = true;
    }

    modifier onlyOwner() { require(msg.sender == owner, "Not owner"); _; }
    modifier onlyAgent() { require(authorizedAgents[msg.sender], "Not agent"); _; }

    function authorizeAgent(address agent) external onlyOwner {
        authorizedAgents[agent] = true;
    }

    function registerPlot(string calldata plotId, bytes32 documentHash) external onlyAgent {
        require(!records[plotId].exists, "Already registered");
        records[plotId] = PlotRecord(documentHash, block.timestamp, msg.sender, true);
    }

    function verifyPlot(string calldata plotId)
        external view returns (bytes32, uint256, address, bool)
    {
        PlotRecord memory r = records[plotId];
        return (r.documentHash, r.timestamp, r.registeredBy, r.exists);
    }

    function validateHash(string calldata plotId, bytes32 hashToCheck)
        external view returns (bool)
    {
        PlotRecord memory r = records[plotId];
        return r.exists && r.documentHash == hashToCheck;
    }
}