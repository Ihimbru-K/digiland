const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("LandVaultRegistry", function () {
  let registry;
  let owner, agent, stranger;

  const PLOT_ID = "LV-2026-0001";
  const FAKE_HASH = ethers.keccak256(ethers.toUtf8Bytes("test-certificate-content"));

  beforeEach(async function () {
    [owner, agent, stranger] = await ethers.getSigners();
    const LandVaultRegistry = await ethers.getContractFactory("LandVaultRegistry");
    registry = await LandVaultRegistry.deploy();
  });

  it("deploys with owner as authorized agent", async function () {
    expect(await registry.authorizedAgents(owner.address)).to.equal(true);
  });

  it("allows owner to authorize a new agent", async function () {
    await registry.authorizeAgent(agent.address);
    expect(await registry.authorizedAgents(agent.address)).to.equal(true);
  });

  it("allows authorized agent to register a plot", async function () {
    await registry.registerPlot(PLOT_ID, FAKE_HASH);
    const [hash, timestamp, registeredBy, exists] = await registry.verifyPlot(PLOT_ID);
    expect(exists).to.equal(true);
    expect(hash).to.equal(FAKE_HASH);
    expect(registeredBy).to.equal(owner.address);
  });

  it("prevents duplicate plot registration", async function () {
    await registry.registerPlot(PLOT_ID, FAKE_HASH);
    await expect(registry.registerPlot(PLOT_ID, FAKE_HASH)).to.be.revertedWith(
      "Plot already registered"
    );
  });

  it("rejects unauthorized agent", async function () {
    await expect(
      registry.connect(stranger).registerPlot(PLOT_ID, FAKE_HASH)
    ).to.be.revertedWith("Not authorized agent");
  });

  it("validates correct hash", async function () {
    await registry.registerPlot(PLOT_ID, FAKE_HASH);
    expect(await registry.validateHash(PLOT_ID, FAKE_HASH)).to.equal(true);
  });

  it("rejects wrong hash", async function () {
    await registry.registerPlot(PLOT_ID, FAKE_HASH);
    const wrongHash = ethers.keccak256(ethers.toUtf8Bytes("tampered-content"));
    expect(await registry.validateHash(PLOT_ID, wrongHash)).to.equal(false);
  });
});
