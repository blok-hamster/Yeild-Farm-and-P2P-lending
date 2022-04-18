const wethToken = artifacts.require("MockWETH");
const daiToken = artifacts.require("MockDAI");
const mockPriceFeed = artifacts.require("MockV3Aggregator");
const Web3 = require("web3")

module.exports = async function(deployer, network, accounts) {
    let decimals = 18
    let priceValue = Web3.utils.toWei("4000", "ether")
    await deployer.deploy(mockPriceFeed, decimals, priceValue);
    await deployer.deploy(daiToken);
    await deployer.deploy(wethToken);
};