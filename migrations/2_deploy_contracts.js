const FlightSuretyApp = artifacts.require("FlightSuretyApp");
const FlightSuretyData = artifacts.require("FlightSuretyData");
const fs = require("fs");

module.exports = function (deployer, network, accounts) {
  let firstAirline = accounts[1];
  deployer.deploy(FlightSuretyData, firstAirline, "Emirates Airline").then((dataContract) => {
    return deployer.deploy(FlightSuretyApp, dataContract.address).then((appContract) => {
      return dataContract.authorizeCaller(appContract.address).then(() => {
        let config = {
          localhost: {
            url: "http://localhost:8545",
            dataAddress: FlightSuretyData.address,
            appAddress: FlightSuretyApp.address,
          },
        };

        fs.writeFileSync(__dirname + "/../src/dapp/config.json", JSON.stringify(config, null, "\t"), "utf-8");
        fs.writeFileSync(__dirname + "/../src/server/config.json", JSON.stringify(config, null, "\t"), "utf-8");
      });
    });
  });
};
