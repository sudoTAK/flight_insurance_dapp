import DOM from "./dom";
import Contract from "./contract";
import "./flightsurety.css";

const flightStatusObj = {
  0: "STATUS_CODE_UNKNOWN",
  10: "STATUS_CODE_ON_TIME",
  20: "STATUS_CODE_LATE_AIRLINE",
  30: "STATUS_CODE_LATE_WEATHER",
  40: "STATUS_CODE_LATE_TECHNICAL",
  50: "STATUS_CODE_LATE_OTHER",
};

(async () => {
  function errorCallback() {
    $("#operation_status").addClass("text-danger").html("Not connected to network");
  }

  let result = null;
  let contract = new Contract(
    "localhost",
    () => {
      //showing balance
      contract.fetchOwnerBalance(getOwnerBalance);
      //end

      contract.isOperational((error, result) => {
        if (result) $("#operation_status").addClass("text-success").html(result);
        else $("#operation_status").addClass("text-danger").html(result);
      });

      //get user wallet balance
      contract.fetchWalletBalance(userWalletBalanceCallback);
      //end

      // check flight statuc
      $("#submit-oracle").on("click", function () {
        if ($("#flights_selection").val() == "Select Flight") {
          alert("Please Select flight to fetch status");
          return;
        }
        $("#flight_status_response").html("");
        showSpinnerInsideDiv("flight_status_response");

        const found = contract.flights.find((flight) => flight[0] == $("#flights_selection").val());
        if (found) {
          contract.fetchFlightStatus(found, (error, result) => {
            if (error) {
              alert(error);
              removeSpinnerFromDiv("flight_status_response");
            } else {
            }
          });
        }
      });

      //buy insurance
      $("#buy-insurance").on("click", function () {
        if ($("#insurance_buy_selection").val() == "Select Flight") {
          alert("Please Select flight to buy insurance");
          return;
        } else if ($("#input_buy_insurance").val() == "") {
          alert("Please provide insurance amount");
          return;
        }

        let buyAmount = parseFloat($("#input_buy_insurance").val());

        if (buyAmount <= 0) {
          alert("Please provide insurance amount greater then zero");
          return;
        }

        const found = contract.flights.find((flight) => flight[0] == $("#insurance_buy_selection").val());
        if (found) {
          contract.buyInsurance(found, buyAmount, buyInsuranceResponseCallback);
        }
        //    $("#buy_insurance_status").html("");
      });
      //endi

      //withdraw balance
      $("#withdraw_balance").on("click", function () {
        contract.withdraw(withdrawWalletBalanceRequestCallback);
      });
      //end

      showFirstAirlineFlights(contract.flights);
      showFetchFlightStatusDropdown(contract.flights);
    },
    errorCallback,
    fligthStatusResponseCallback,
    creditWalletEventCallback,
    withdrawWalletBalanceEventCallback
  );

  //helper functions
  function showFirstAirlineFlights(flights) {
    let ele = $("#flight_table > tbody");
    flights.forEach((flight, index) => {
      let row = '<tr><th scope="row">' + (index + 1) + "</th>";
      row += "<td>" + flight[0] + "</td>";
      row += "<td>" + flight[1] + "</td>";
      row += "<td>" + flight[2] + "</td> </tr>";
      $(ele).append(row);
    });
  }

  function showFetchFlightStatusDropdown(flights) {
    let ele = $(".flights_selection");
    var o = new Option("Select Flight", "Select Flight");
    $(o).html("Select Flight");
    $(ele).append(o);
    flights.forEach((flight, index) => {
      var o = new Option(flight[0], flight[0]);
      $(o).html(flight[0]);
      $(ele).append(o);
    });
  }

  function fligthStatusResponseCallback(err, result) {
    removeSpinnerFromDiv("flight_status_response");
    if (err) {
      $("#flight_status_response").html(`<p class="text-danger">Error fetching status, please try again</p>`);
    } else {
      $("#flight_status_response").html(`<p class="text-success">${flightStatusObj[result.returnValues.status]}</p>`);
    }
  }

  function showSpinnerInsideDiv(appendWhere) {
    let ele = $("#" + appendWhere);
    let item = `<div class="spinner-grow" role="status">
      <span class="visually-hidden">Loading...</span>
      </div>
      `;
    $(ele).append(item);
  }

  function removeSpinnerFromDiv(removeFromWhere) {
    let ele = $("#" + removeFromWhere);
    $(ele);
    $("#" + removeFromWhere)
      .find(".spinner-grow")
      .remove();
  }

  function getOwnerBalance(balance) {
    $("#buy_insurance_status")
      .addClass("text-success")
      .html("Current Balance in ether: " + balance);
  }

  function buyInsuranceResponseCallback(err, result) {
    if (err) {
      alert(err);
      return;
    }
    alert("Insurance bought successfully. Tx id : " + result);
    contract.fetchOwnerBalance(getOwnerBalance);
  }

  function creditWalletEventCallback(err, result) {
    setTimeout(() => {
      if (err) {
        alert(err);
        return;
      }
      contract.fetchWalletBalance(userWalletBalanceCallback);
      alert(`
      Your wallet is credited with amount ${contract.web3.utils.fromWei(result.returnValues.amount, "ether")} ether. 
      Credit Reason : ${result.returnValues.creditReason}.
      You can withdraw it anytime you want`);
    }, 2000);
  }

  function userWalletBalanceCallback(err, result) {
    if (err) {
      alert(err);
      return;
    }
    $("#wallet_balance").html("Wallet Balance : " + contract.web3.utils.fromWei(result, "ether") + " ether");
  }

  function withdrawWalletBalanceEventCallback(err, result) {
    setTimeout(() => {
      if (err) {
        alert(err);
        return;
      }
      contract.fetchWalletBalance(userWalletBalanceCallback);
      contract.fetchOwnerBalance(getOwnerBalance);
      alert(`
      You have successfully withdrawn your wallet balance to your adderress.
      Amount withdrawn :  ${contract.web3.utils.fromWei(result.returnValues.amount, "ether")} ether.`);
    }, 1000);
  }

  function withdrawWalletBalanceRequestCallback(err, result) {
    if (err) {
      alert(err);
      return;
    }
    alert("Withdraw request sent successfully. Tx id : " + result);
  }
})();
