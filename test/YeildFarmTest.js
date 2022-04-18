const YieldFarm = artifacts.require("YieldFarm");
const TestToken = artifacts.require("TestToken");
const Credit = artifacts.require("Credit");

//Dev Mocks: these are mock's for testing and wouldnt be needed in production
const mockPriceFeed = artifacts.require("MockV3Aggregator");
const daiToken = artifacts.require("MockDAI");
const wethToken = artifacts.require("MockWETH");

const truffleAssert = require("truffle-assertions")
const Web3 = require("web3")

contract("YieldFarm", accounts => {
    
    it("only owner should add token", async() => {
        
        let yieldFarm = await YieldFarm.deployed()
        let TST = await TestToken.deployed()
        let DAI = await daiToken.deployed()
        let WETH = await wethToken.deployed()

        let TestTokenAmount = Web3.utils.toWei("10000", "ether")

        await TST.transfer(yieldFarm.address, TestTokenAmount)

        //This should revert because accounts[1] is not the owner
        await truffleAssert.reverts(
            yieldFarm.addAllowedTokens(TST.address, { from: accounts[1] })
        )
        await truffleAssert.passes(
            yieldFarm.addAllowedTokens(TST.address, { from: accounts[0] })
        )
        await truffleAssert.passes(
            yieldFarm.addAllowedTokens(DAI.address, { from: accounts[0] })
        )
        await truffleAssert.passes(
            yieldFarm.addAllowedTokens(WETH.address, { from: accounts[0] })
        )
    })

    it("only owner should add price feed", async() => {

        let priceFeed = await mockPriceFeed.deployed()
        let yieldFarm = await YieldFarm.deployed()
        let TST = await TestToken.deployed()
        let DAI = await daiToken.deployed()
        let WETH = await wethToken.deployed()

        await truffleAssert.reverts(
            yieldFarm.setPriceFeedAddress(TST.address, priceFeed.address, {from: accounts[2]})
        )

        await truffleAssert.passes(
            yieldFarm.setPriceFeedAddress(TST.address, priceFeed.address, {from: accounts[0]})
        )

        await truffleAssert.passes(
            yieldFarm.setPriceFeedAddress(DAI.address, priceFeed.address, {from: accounts[0]})
        )

        await truffleAssert.passes(
            yieldFarm.setPriceFeedAddress(WETH.address, priceFeed.address, {from: accounts[0]})
        )

    })

    it("User can satke", async() => {
        let yieldFarm = await YieldFarm.deployed()
        let TST = await TestToken.deployed()
        
        await TST.transfer(accounts[2], 200)
        await TST.approve(yieldFarm.address, 100, {from: accounts[2]})
        await yieldFarm.stakeTokens(100, TST.address, {from: accounts[2]})

        assert.equal(await yieldFarm.stakingBalance(TST.address, accounts[2]), 100)
        assert.equal(await yieldFarm.uniqueTokensStaked(accounts[2]), 1)
        assert.equal(await yieldFarm.stakers(0), accounts[2])
    })

    it("can issue tokens to users with stakes.", async() => {
        let yieldFarm = await YieldFarm.deployed()
        let TST = await TestToken.deployed()

        let startBalance = await TST.balanceOf(accounts[0])

        await yieldFarm.issueRewardTokens()
        let endBalance = await TST.balanceOf(accounts[0])
        assert.equal(
            parseInt(endBalance), parseInt(startBalance) + (Web3.utils.toWei("2000", "ether") / 10 ** 16)
        )
    })

    it("user can unstake", async() => {
        let yieldFarm = await YieldFarm.deployed()
        let TST = await TestToken.deployed()
        
        await TST.transfer(accounts[2], 200)
        await TST.approve(yieldFarm.address, 100, {from: accounts[2]})
        await yieldFarm.stakeTokens(100, TST.address, {from: accounts[2]})
        
        await truffleAssert.passes(
            await yieldFarm.unstakeToken(TST.address, {from: accounts[2]})
        )  
        
    })

    it("user can create credit", async() => {
        const yieldFarm = await YieldFarm.deployed()
        
        await truffleAssert.passes(
            await yieldFarm.applyForCredit(20, 4, 2, "Project Lone", {from: accounts[2]})
        )  
        
    })

})