const TestToken = artifacts.require("TestToken");

module.exports = function(deployer, network, accounts) {
    deployer.deploy(TestToken);
};