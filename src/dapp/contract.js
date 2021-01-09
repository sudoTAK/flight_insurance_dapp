import FlightSuretyApp from "../../build/contracts/FlightSuretyApp.json";
import FlightSuretyData from "../../build/contracts/FlightSuretyData.json";

import Config from "./config.json";
import Web3 from "web3";

export default class Contract {
  constructor(network, callback, errorCallback, fligthStatusResponseCallback, creditWalletEventCallback, withdrawWalletBalanceEventCallback) {
    let config = Config[network];
    this.web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace("http", "ws")));

    this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress, { gasLimit: 3000000 });
    this.flightSuretyData = new this.web3.eth.Contract(FlightSuretyData.abi, config.dataAddress, { gasLimit: 3000000 });
    this.initialize(callback, errorCallback, creditWalletEventCallback, withdrawWalletBalanceEventCallback);
    this.owner = null;
    this.airlines = [];
    this.passengers = [];
    this.flights = [];

    this.flightSuretyApp.events.FlightStatusInfo({ fromBlock: "latest" }, (err, result) => {
      fligthStatusResponseCallback(err, result);
    });
  }

  initialize(callback, errorCallback, creditWalletEventCallback, withdrawWalletBalanceEventCallback) {
    this.web3.eth.getAccounts((error, accts) => {
      if (error) {
        errorCallback();
        return;
      }
      this.owner = accts[0];

      //setup event listner for user wallet credit in case flight get canceled
      //filter event listening only for this owner wallet
      this.flightSuretyData.events.WalletCredited({ filter: { userWalletAddress: this.owner }, fromBlock: "latest" }, (err, result) => {
        console.dir(err);
        console.dir(result);
        creditWalletEventCallback(err, result);
      });
      //   end

      //setup event listner for user withdrawing wallet balance.
      //filter event by useraddress only
      this.flightSuretyApp.events.AmountTransferedToUser({ filter: { userWalletAddress: this.owner }, fromBlock: "latest" }, (err, result) => {
        console.dir(result);
      //  alert(result.returnValues.amount);
       withdrawWalletBalanceEventCallback(err, result);
      });
      //end

      let counter = 1;

      this.flights.push(["JAPAN UND1", Math.floor(Date.now() / 1000) + 24 * 60 * 60, accts[1]]);
      this.flights.push(["JAPAN ND102", Math.floor(Date.now() / 1000) + 25 * 60 * 60, accts[1]]);
      this.flights.push(["JAPAN JD784", Math.floor(Date.now() / 1000) + 26 * 60 * 60, accts[1]]);

      while (this.airlines.length < 5) {
        this.airlines.push(accts[counter++]);
      }

      while (this.passengers.length < 5) {
        this.passengers.push(accts[counter++]);
      }

      callback();
    });
  }

  isOperational(callback) {
    let self = this;
    self.flightSuretyApp.methods.isOperational().call({ from: self.owner }, callback);
  }

  fetchFlightStatus(flight, callback) {
    let self = this;
    let payload = {
      airline: flight[2],
      flight: flight[0],
      timestamp: flight[1],
    };
    self.flightSuretyApp.methods.fetchFlightStatus(payload.airline, payload.flight, payload.timestamp).send({ from: self.owner }, (error, result) => {
      callback(error, result);
    });
  }

  fetchOwnerBalance(get_balance_callback) {
    let self = this;
    self.web3.eth.getBalance(self.owner).then((bal) => get_balance_callback(self.web3.utils.fromWei(bal, "ether")));
  }

  buyInsurance(flight, amount, callback) {
    let self = this;
    let payload = {
      airline: flight[2],
      flight: flight[0],
      timestamp: flight[1],
    };
    self.flightSuretyApp.methods
      .buyInsurance(payload.airline, payload.flight, payload.timestamp)
      .send({ from: self.owner, value: self.web3.utils.toWei(amount + "", "ether") }, (error, result) => callback(error, result));
  }

  fetchWalletBalance(userWalletBalanceCallback) {
    let self = this;
    self.flightSuretyApp.methods.getMyWalletBalance().call({ from: self.owner }, (error, result) => {
      userWalletBalanceCallback(error, result);
    });
  }

  withdraw(withdrawWalletBalanceRequestCallback){
    let self = this;
    self.flightSuretyApp.methods.withdraw().send({ from: self.owner }, (error, result) => {
      withdrawWalletBalanceRequestCallback(error, result);
    });
  }

}
