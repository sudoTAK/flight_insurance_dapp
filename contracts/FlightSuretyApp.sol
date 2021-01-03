pragma solidity ^0.4.25;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
	using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

	/********************************************************************************************/
	/*                                       DATA VARIABLES                                     */
	/********************************************************************************************/

	// Flight status codees
	uint8 private constant STATUS_CODE_UNKNOWN = 0;
	uint8 private constant STATUS_CODE_ON_TIME = 10;
	uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
	uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
	uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
	uint8 private constant STATUS_CODE_LATE_OTHER = 50;

	address private contractOwner; // Account used to deploy contract

	FlightSuretyData flightSuretyData; //data contract instance

	/********************************************************************************************/
	/*                                       FUNCTION MODIFIERS                                 */
	/********************************************************************************************/

	// Modifiers help avoid duplication of code. They are typically used to validate something
	// before a function is allowed to be executed.

	/**
	 * @dev Modifier that requires the "operational" boolean variable to be "true"
	 *      This is used on all state changing functions to pause the contract in
	 *      the event there is an issue that needs to be fixed
	 */
	modifier requireIsOperational() {
		// Modify to call data contract's status
		require(isOperational(), "Contract is currently not operational");
		_; // All modifiers require an "_" which indicates where the function body will be added
	}

	/**
	 * @dev Modifier that requires the "ContractOwner" account to be the function caller
	 */
	modifier requireContractOwner() {
		require(msg.sender == contractOwner, "Caller is not contract owner");
		_;
	}

	/**
	 * @dev Modifier that requires the "isAirlineExists" boolean variable to be "false"
	 */
	modifier isAirlineExists(address airlineAddress) {
		// Modify to call data contract's status
		require(!flightSuretyData.isAirlineExists(airlineAddress), "Airline already Registered");
		_; // All modifiers require an "_" which indicates where the function body will be added
	}

	/**
	 * @dev Modifier that requires the "hasAirlineFunded" boolean variable to be "false"
	 */
	modifier hasAirlineFunded(address airlineAddress) {
		// Modify to call data contract's status
		require(flightSuretyData.hasAirlineFunded(airlineAddress), "Airline has not funded the contract");
		_; // All modifiers require an "_" which indicates where the function body will be added
	}

	/********************************************************************************************/
	/*                                       CONSTRUCTOR                                        */
	/********************************************************************************************/

	/**
	 * @dev Contract constructor
	 *
	 */
	constructor(address dataContract) public {
		contractOwner = msg.sender;
		flightSuretyData = FlightSuretyData(dataContract);
	}

	/********************************************************************************************/
	/*                                       UTILITY FUNCTIONS                                  */
	/********************************************************************************************/

	function isOperational() public view returns (bool) {
		return flightSuretyData.isOperational(); // Modify to call data contract's status
	}

	function isAirline(address addRess) public view returns (bool) {
		return flightSuretyData.isAirlineExists(addRess);
	}

	/**
	 * @dev method to check if airline already registered or not. called from app contract
	 */
	function isAirlineFunded(address airlineAddress) external view requireIsOperational returns (bool) {
		return flightSuretyData.hasAirlineFunded(airlineAddress);
	}

	/// @notice converts number to string
	/// @dev source: https://github.com/provable-things/ethereum-api/blob/master/oraclizeAPI_0.5.sol#L1045
	/// @param _i integer to convert
	/// @return _uintAsString
	function uintToStr(uint256 _i) internal pure returns (string memory _uintAsString) {
		uint256 number = _i;
		if (number == 0) {
			return "0";
		}
		uint256 j = number;
		uint256 len;
		while (j != 0) {
			len++;
			j /= 10;
		}
		bytes memory bstr = new bytes(len);
		uint256 k = len - 1;
		while (number != 0) {
			bstr[k--] = bytes1(uint8(48 + (number % 10)));
			number /= 10;
		}
		return string(bstr);
	}

	/********************************************************************************************/
	/*                                     SMART CONTRACT FUNCTIONS                             */
	/********************************************************************************************/

	/**
	 * @dev Add an airline to the registration queue
	 *  empty airlines name not allowed
	 */
	function registerAirline(address airlineAddress, string name)
		external
		requireIsOperational
		isAirlineExists(airlineAddress) // checking if airline is already registered
		returns (bool success, uint256 votes)
	{
		bytes memory tempEmptyStringTest = bytes(name);
		require(tempEmptyStringTest.length > 0, "Airline name not provided"); //fail fast if airline name is empty
		//	address[] registeredAirlineArray;
		address[] memory getRegisteredAirlineArr = flightSuretyData.getRegisteredAirlineArr();
		if (getRegisteredAirlineArr.length < 4) {
			require(
				flightSuretyData.isAirlineExists(msg.sender),
				"Only Registered Airline can registered another airline till total registered airlins are upto 4"
			);
			require(flightSuretyData.hasAirlineFunded(msg.sender), "Only Airlines who have funded the contract are eligible to register another airline");
			flightSuretyData.registerAirline(airlineAddress, name);
			return (true, 0);
		} else {
			uint256 voteRequired = getRegisteredAirlineArr.length.div(2); //fifty percent required
			if (getRegisteredAirlineArr.length % 2 != 0) voteRequired = voteRequired + 1; // upperbound we take. i.e if 7/2, we need four vots not 3.5

			uint256 voteGained = 0;
			bool isDuplicate = false;
			//check if msg.sender already added provided airline to pool.
			if (!flightSuretyData.isAirlinInForRegistration(airlineAddress, msg.sender)) {
				//if not, then add this airline to pool and wait for 50% vote.
				//note : this does not mean one vote is given, it just means pooling. vote count will be calculated later in the method
				flightSuretyData.addToNewAirlineVotePool(airlineAddress, msg.sender);
			} else {
				//fail fast
				if (!flightSuretyData.hasAirlineFunded(msg.sender)) {
					require(!true, "You have already added this airline in registration pool, you need to fund to cast your vote.");
				}
				isDuplicate = true;
			}

			uint256 totalRegisteredAirlines = getRegisteredAirlineArr.length;
			for (uint256 i = 0; i < totalRegisteredAirlines; i++) {
				//check if the airlin to be registered is already in pool and the msg.sender has funded. if both true, increment one vote.
				if (flightSuretyData.addedToPoolAndHasFunded(airlineAddress, getRegisteredAirlineArr[i])) {
					voteGained = voteGained + 1;
				}
				if (voteGained == voteRequired) {
					//we have got enought vote, now register the airline
					flightSuretyData.registerAirline(airlineAddress, name);
					//delete all references from storage, as it is no longer required in pending pool
					flightSuretyData.deletePendingAirlineFromPool(airlineAddress);
					return (true, voteGained);
				}
			}

			// no need for this require statement, i have included it to show proper test error during testing
			require(
				isDuplicate == false,
				string(
					abi.encodePacked(
						"Not enought vote gained, more vote needed = ",
						uintToStr(voteRequired - voteGained),
						", total registered = ",
						uintToStr(totalRegisteredAirlines),
						", voteRequired = ",
						uintToStr(voteRequired),
						", vote gained = ",
						uintToStr(voteGained)
					)
				)
			);
			return (false, voteGained);
		}
	}

	/**
	 * @dev Initial funding for the insurance. Unless there are too many delayed flights
	 *      resulting in insurance payouts, the contract should be self-sustaining
	 */
	function fund() public payable requireIsOperational {
		//check if amount is ok.
		require(
			msg.value == flightSuretyData.getAirlineInitialFundAmount(),
			string(abi.encodePacked("Invalid amount sent. Check valid amount using getAirlineInitialFundAmount"))
		);
		flightSuretyData.fund.value(msg.value)(msg.sender);
	}

	/**
	 * @dev Register a future flight for insuring.
	 *
	 */
	function registerFlight(string flight, uint256 timestamp) public requireIsOperational {
		require(flightSuretyData.isAirlineExists(msg.sender), "Only Registered Airline can register flights");
		require(flightSuretyData.hasAirlineFunded(msg.sender), "Only Airlines who have funded the contract can register its flights");
		flightSuretyData.registerFlight(msg.sender, flight, timestamp);
	}

	/**
	 * @dev send back insuance amount to user account from userwallet balance
	 *
	 */
	function withdraw() public payable requireIsOperational {
		require(flightSuretyData.getUserBalance(msg.sender) > 0, "User balance is nil");
		flightSuretyData.pay(msg.sender);
	}

	/**
	 * user will call this method from dapp to buy insurance
	 */
	function buyInsurance(bytes32 flightKey) external payable requireIsOperational {
		require(
			msg.value > 0 && msg.value <= flightSuretyData.getFlightInsuranceCapAmount(),
			"Invalid insurance buying amount, call getFlightInsuranceCapAmount to know allowed range"
		);
		require(flightSuretyData.isFlightExists(flightKey), "Invalid flight, flight does not exists in our system");
		flightSuretyData.buy(flightKey, msg.sender);
	}

	/**
	 * @dev Called after oracle has updated flight status
	 *
	 */
	function processFlightStatus(
		address airline,
		string memory flight,
		uint256 timestamp,
		uint8 statusCode
	) internal requireIsOperational {
		//return money if filght delayed
		if (statusCode == STATUS_CODE_LATE_AIRLINE) {
			//initiat credit to user wallet, transfer only when user call withdraw method
			flightSuretyData.creditInsurees(keccak256(abi.encodePacked(airline, flight, timestamp)));
		} else {
			//noting to do for know, FlightStatusInfo event already called
		}
	}

	// Generate a request for oracles to fetch flight information
	function fetchFlightStatus(
		address airline,
		string flight,
		uint256 timestamp
	) external {
		uint8 index = getRandomIndex(msg.sender);

		// Generate a unique key for storing the request
		bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
		oracleResponses[key] = ResponseInfo({ requester: msg.sender, isOpen: true });

		emit OracleRequest(index, airline, flight, timestamp);
	}

	// region ORACLE MANAGEMENT

	// Incremented to add pseudo-randomness at various points
	uint8 private nonce = 0;

	// Fee to be paid when registering oracle
	uint256 public constant REGISTRATION_FEE = 1 ether;

	// Number of oracles that must respond for valid status
	uint256 private constant MIN_RESPONSES = 3;

	struct Oracle {
		bool isRegistered;
		uint8[3] indexes;
	}

	// Track all registered oracles
	mapping(address => Oracle) private oracles;

	// Model for responses from oracles
	struct ResponseInfo {
		address requester; // Account that requested status
		bool isOpen; // If open, oracle responses are accepted
		mapping(uint8 => address[]) responses; // Mapping key is the status code reported
		// This lets us group responses and identify
		// the response that majority of the oracles
	}

	// Track all oracle responses
	// Key = hash(index, flight, timestamp)
	mapping(bytes32 => ResponseInfo) private oracleResponses;

	// Event fired each time an oracle submits a response
	event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

	event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

	// Event fired when flight status request is submitted
	// Oracles track this and if they have a matching index
	// they fetch data and submit a response
	event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);

	// Register an oracle with the contract
	function registerOracle() external payable {
		// Require registration fee
		require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

		uint8[3] memory indexes = generateIndexes(msg.sender);

		oracles[msg.sender] = Oracle({ isRegistered: true, indexes: indexes });
	}

	function getMyIndexes() external view returns (uint8[3]) {
		require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

		return oracles[msg.sender].indexes;
	}

	// Called by oracle when a response is available to an outstanding request
	// For the response to be accepted, there must be a pending request that is open
	// and matches one of the three Indexes randomly assigned to the oracle at the
	// time of registration (i.e. uninvited oracles are not welcome)
	function submitOracleResponse(
		uint8 index,
		address airline,
		string flight,
		uint256 timestamp,
		uint8 statusCode
	) external {
		require(
			(oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index),
			"Index does not match oracle request"
		);

		bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
		require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

		oracleResponses[key].responses[statusCode].push(msg.sender);

		// Information isn't considered verified until at least MIN_RESPONSES
		// oracles respond with the *** same *** information
		emit OracleReport(airline, flight, timestamp, statusCode);
		if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {
			emit FlightStatusInfo(airline, flight, timestamp, statusCode);

			// Handle flight status as appropriate
			processFlightStatus(airline, flight, timestamp, statusCode);
		}
	}

	function getFlightKey(
		address airline,
		string flight,
		uint256 timestamp
	) internal pure returns (bytes32) {
		return keccak256(abi.encodePacked(airline, flight, timestamp));
	}

	// Returns array of three non-duplicating integers from 0-9
	function generateIndexes(address account) internal returns (uint8[3]) {
		uint8[3] memory indexes;
		indexes[0] = getRandomIndex(account);

		indexes[1] = indexes[0];
		while (indexes[1] == indexes[0]) {
			indexes[1] = getRandomIndex(account);
		}

		indexes[2] = indexes[1];
		while ((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
			indexes[2] = getRandomIndex(account);
		}

		return indexes;
	}

	// Returns array of three non-duplicating integers from 0-9
	function getRandomIndex(address account) internal returns (uint8) {
		uint8 maxValue = 10;

		// Pseudo random number...the incrementing nonce adds variation
		uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

		if (nonce > 250) {
			nonce = 0; // Can only fetch blockhashes for last 256 blocks so we adapt
		}

		return random;
	}

	// endregion
}

contract FlightSuretyData {
	function isOperational() external view returns (bool);

	function isAirlineExists(address) external view returns (bool);

	function hasAirlineFunded(address airlineAddress) external view returns (bool);

	function getRegisteredAirlineArr() external view returns (address[] memory);

	function registerAirline(address airlineAddress, string name) external;

	function isAirlinInForRegistration(address pendingAirline, address registeredAirline) external view returns (bool);

	function addToNewAirlineVotePool(address newAirlineToBeRegistrered, address msgSenderAddress) external;

	function addedToPoolAndHasFunded(address pendingRegistration, address msgSenderAddress) external returns (bool);

	function deletePendingAirlineFromPool(address pendingAirline) external;

	function getAirlineInitialFundAmount() external returns (uint256);

	function fund(address senderAddress) external payable; //airline need to fund before talkin part in contract

	function registerFlight(
		address airline,
		string flight,
		uint256 timestamp
	) external;

	function pay(address userAddress) external; // called to transfer money to user account 1.5 times of insurance amount

	function getUserBalance(address userAddress) external returns (uint256);

	function creditInsurees(bytes32 flightKey) external; //called to credit userbalance for fligh delay

	function buy(bytes32 flightKey, address userAddress) external payable; //called to buy insurance

	function getFlightInsuranceCapAmount() external returns (uint256);

	function isFlightExists(bytes32 flightKey) external returns (bool);
}
