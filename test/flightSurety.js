var Test = require("../config/testConfig.js");
var BigNumber = require("bignumber.js");

contract("Flight Surety Tests", async (accounts) => {
  var config;
  before("setup contract", async () => {
    config = await Test.Config(accounts);
    await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`1(multiparty) has correct initial isOperational() value`, async function () {
    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");
  });

  it(`2(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {
    // Ensure that access is denied for non-Contract Owner account
    let accessDenied = false;
    try {
      await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
    } catch (e) {
      accessDenied = true;
    }
    assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
  });

  it(`3(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {
    // Ensure that access is allowed for Contract Owner account
    let accessDenied = false;
    try {
      await config.flightSuretyData.setOperatingStatus(false);
    } catch (e) {
      accessDenied = true;
    }
    assert.equal(accessDenied, false, "Access not restricted to Contract Owner");
    await config.flightSuretyData.setOperatingStatus(true);
  });

  it(`4(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {
    await config.flightSuretyData.setOperatingStatus(false);
    let reverted = false;
    try {
      await config.flightSuretyData.setTestingMode(true);
    } catch (e) {
      reverted = true;
    }
    assert.equal(reverted, true, "Access not blocked for requireIsOperational");

    // Set it back for other tests to work
    await config.flightSuretyData.setOperatingStatus(true);
  });

  it("5(airline) cannot register an Airline using registerAirline() if it is not funded", async () => {
    // ARRANGE
    let newAirline = accounts[2];

    // ACT
    try {
      await config.flightSuretyApp.registerAirline(newAirline, "Japan Airways", { from: config.firstAirline });
    } catch (e) {}
    let result = await config.flightSuretyApp.isAirline.call(newAirline);

    // ASSERT
    assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");
  });

  it(`6(airline) fund first airline and validate that only set amount is funded`, async function () {
    let reverted = false;
    try {
      await config.flightSuretyApp.fund({ from: config.firstAirline, value: 5 });
    } catch (e) {
      reverted = true;
    }
    assert.equal(reverted, true, "Accept only allowed fund amount, but accepting any");
  });

  it(`7(airline) fund first airline and validate the airline is funded status`, async function () {
    let noFunded = await config.flightSuretyApp.isAirlineFunded(config.firstAirline);
    let isFunded;
    try {
      await config.flightSuretyApp.fund({ from: config.firstAirline, value: 10 });
      isFunded = await config.flightSuretyApp.isAirlineFunded(config.firstAirline);
    } catch (e) {}
    assert.equal(noFunded, !isFunded, "Airline fund status should be changed to funded, but not changed");
  });

  it("8(airline) should register an Airline using registerAirline() if it is funded", async () => {
    // ARRANGE
    let newAirline = accounts[2];
    // ACT
    try {
      await config.flightSuretyApp.registerAirline(newAirline, "Japan Airways", { from: config.firstAirline }); //first airline already funded in test no. 7
    } catch (e) {}
    let result = await config.flightSuretyApp.isAirline.call(newAirline);

    // ASSERT
    assert.equal(result, true, "funded Airline should be able to register another airline but could not register");
  });

  it("9(airline) Only existing airline may register a new airline until there are at least four airlines registered", async () => {
    // ARRANGE // two already registered in above tests, register 2 more and should fail when registering 5th one
    let airline3 = accounts[3];
    let airline4 = accounts[4];
    let airline5 = accounts[5];

    await config.flightSuretyApp.registerAirline(airline3, "Korea Airways", { from: config.firstAirline });
    await config.flightSuretyApp.registerAirline(airline4, "China Airways", { from: config.firstAirline });
    // ACT
    try {
      await config.flightSuretyApp.registerAirline(airline5, "Candada Airways", { from: config.firstAirline });
    } catch (e) {
      console.log(e);
    }

    let result3 = await config.flightSuretyApp.isAirline.call(airline3);
    let result4 = await config.flightSuretyApp.isAirline.call(airline4);

    let result5 = await config.flightSuretyApp.isAirline.call(airline5);

    // ASSERT
    assert.equal(result3, true, "Airline registration of 3rd one should pass");
    assert.equal(result4, true, "Airline registration of 4th one should pass");
    assert.equal(result5, false, "Airline registration of 5th one should fail");
  });
});
