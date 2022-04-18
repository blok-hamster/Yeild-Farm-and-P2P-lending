const YieldFarm = artifacts.require("YieldFarm");
const TestToken = artifacts.require("TestToken");
const Credit = artifacts.require("Credit");

module.exports = async function(deployer, network, accounts) {
    const token = await TestToken.deployed();
    const tokenAddress = token.address;
    await deployer.deploy(YieldFarm, tokenAddress);
    console.log("Token Address: " + tokenAddress);
};