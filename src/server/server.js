import FlightSuretyApp from "../../build/contracts/FlightSuretyApp.json";
import Config from "./config.json";
import Web3 from "web3";
import express from "express";

let config = Config["localhost"];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace("http", "ws")));
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress, { gasLimit: 3000000 });

//status code for flights
const STATUS_CODE_UNKNOWN = 0;
const STATUS_CODE_ON_TIME = 10;
const STATUS_CODE_LATE_AIRLINE = 20;
const STATUS_CODE_LATE_WEATHER = 30;
const STATUS_CODE_LATE_TECHNICAL = 40;
const STATUS_CODE_LATE_OTHER = 50;
const statusCodesArr = [
  STATUS_CODE_UNKNOWN,
  STATUS_CODE_ON_TIME,
  STATUS_CODE_LATE_AIRLINE,
  STATUS_CODE_LATE_WEATHER,
  STATUS_CODE_LATE_TECHNICAL,
  STATUS_CODE_LATE_OTHER,
];

const app = express();

(async () => {
  const TEST_ORACLES_COUNT = 5; //make sure you have created this number or more number of wallets addresses
  const oracles = [];

  const fee = await flightSuretyApp.methods.REGISTRATION_FEE().call();
  const accounts = await web3.eth.getAccounts();

  //Oracle Initialization
  //Upon startup, 20+ oracles are registered and their assigned indexes are persisted in memory. TAK
  for (let a = 1; a < TEST_ORACLES_COUNT; a++) {
    await flightSuretyApp.methods.registerOracle().send({ from: accounts[a], value: fee });
    let result = await flightSuretyApp.methods.getMyIndexes().call({ from: accounts[a] });
    console.log(`${a} Oracle Registered: ${result[0]}, ${result[1]}, ${result[2]}`);
    // push account in result and then push result in oracles to maintain temp memory persistance.
    //pushing acount to result will help in handling OracleRequest event
    result.push(accounts[a]);
    oracles.push(result);
  }

  //Oracle Functionality
  //Server will loop through all registered oracles, identify those oracles for which the OracleRequest
  // event applies, and respond by calling into FlightSuretyApp contract with random status code of
  //Unknown (0), On Time (10) or Late Airline (20), Late Weather (30), Late Technical (40), or Late Other (50). TAK
  const handleOracleRequest = (err, result) => {
    console.log(result);
    if (err) return;
    //get random status code
    const randomStatusCode = statusCodesArr[Math.floor(Math.random() * statusCodesArr.length)];
    console.log("sending status code " + statusCode);

    const { index, airline, flight, timestamp } = result.returnValues;
    for (const oracle of oracles) {
      for (let idx = 0; idx < 3; idx++) {
        //since we don't know which oracle's index will be equal to the "index" return by oraclerequest event.
        flightSuretyApp.methods
          .submitOracleResponse(oracle[idx], airline, flight, timestamp, randomStatusCode)
          .call({ from: oracle[3] })
          .catch((e) => {
            // console.log(e);
          });
      }
    }
  };

  //Oracle Updates : Update flight status requests from client Dapp result in OracleRequest event
  //emitted by Smart Contract that is captured by server (displays on console and handled in code). TAK
  flightSuretyApp.events.OracleRequest({ fromBlock: "latest" }, handleOracleRequest);

  //simulating to trigger oraclerequest event. TAK
  //trigger app contract OracleRequest event by calling fetchFlightStatus method
  //uncomment to start simulation or else simulate from client side
  let flight = "ND1309"; // Course number
  let timestamp = Math.floor(Date.now() / 1000);
  setTimeout(async () => {
    console.log("calling now");
    await flightSuretyApp.methods.fetchFlightStatus(accounts[1], flight, timestamp).send({ from: accounts[1] });
  }, 5000);
  //end
})();
app.get("/api", (req, res) => {
  res.send({
    message: "An API for use with your Dapp!",
  });
});

export default app;
