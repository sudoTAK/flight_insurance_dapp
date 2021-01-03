pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
	using SafeMath for uint256;

	/********************************************************************************************/
	/*                                       DATA VARIABLES                                     */
	/********************************************************************************************/
	uint8 private constant STATUS_CODE_ON_TIME = 10;

	address private contractOwner; // Account used to deploy contract
	bool private operational = true; // Blocks all state changes throughout the contract if false
	address private authorizeAppContract; // Account allowed to access this contract

	uint256 private airlineInitialFundAmount = 10 ether; // airlines have to pay 10 ether. this can be changed by contract owner. helper function provided.
	uint256 private flightInsuranceCapAmount = 1 ether; // auser can buy insurance by paying upto 1 ether.

	mapping(address => Airline) private registeredAirlinesMap;
	address[] private registeredAirlineArray = new address[](0);

	mapping(address => mapping(address => bool)) private addressToVoteCountMapping;

	//this his helper mapping will be used to delete all entry from addressToVoteCountMapping and
	//then from iteself after the pending airline is registered with enought votes.
	//this is done to efficiently save storage and gas because solidity do not provide a way to
	//delete key from mapping if mapping is typeof like mapping(address => mapping(address=> bool));
	//see its utilization in deletePendingAirlineFromPool method below
	mapping(address => address[]) private pendingAirlineMapping;

	struct Airline {
		string name;
		bool isRegistered;
		bool hasFunded;
	}

	struct Flight {
		bool isRegistered;
		uint8 statusCode;
		uint256 updatedTimestamp;
		address airline;
		string name;
	}
	mapping(bytes32 => Flight) private flights;

	bytes32[] flightsKeyArr; //will be used to iterate flights mapping and will send the result to user's frontend

	struct Insured {
		bool isInsured;
		address[] insuredPassengers;
		mapping(address => uint256) insuredAmountMapping;
	}

	mapping(bytes32 => Insured) boughtInsurance;

	mapping(address => uint256) userWallet;

	/********************************************************************************************/
	/*                                       EVENT DEFINITIONS                                  */
	/********************************************************************************************/
	event WalletCredited(address userWalletAddress, uint256 amount, string creditReason);
	event AmountTransferedToUser(address userWalletAddress, uint256 amount);

	/**
	 * @dev Constructor
	 *      The deploying account becomes contractOwner
	 */
	constructor(address firstAirline, string name) public {
		contractOwner = msg.sender;
		//creating first airline during deployment of data contract.
		registeredAirlineArray.push(firstAirline);
		registeredAirlinesMap[firstAirline] = Airline(name, true, false);
	}

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
		require(operational, "Contract is currently not operational");
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
	 * @dev Modifier that requires the registered APP contract account to be the function caller
	 */
	modifier requireAuthorizeCaller() {
		require(msg.sender == authorizeAppContract, "Caller is not authorize contract");
		_;
	}

	/********************************************************************************************/
	/*                                       UTILITY FUNCTIONS                                  */
	/********************************************************************************************/

	/**
	 * @dev Get operating status of contract
	 *
	 * @return A bool that is the current operating status
	 */
	function isOperational() public view returns (bool) {
		return operational;
	}

	/**
	 * @dev Sets contract operations on/off
	 *
	 * When operational mode is disabled, all write transactions except for this one will fail
	 */
	function setOperatingStatus(bool mode) external requireContractOwner {
		require(mode != operational, "New mode must be different from existing mode");
		operational = mode;
	}

	/**
	 * @dev Sets airlineInitialFundAmount
	 */
	function setAirlineInitialFundAmount(uint256 amount) public requireContractOwner {
		require(amount != airlineInitialFundAmount, "New amount must be different from existing amount");
		airlineInitialFundAmount = amount;
	}

	/**
	 * @dev gets airlineInitialFundAmount
	 */
	function getAirlineInitialFundAmount() external view requireAuthorizeCaller returns (uint256) {
		return airlineInitialFundAmount;
	}

	/**
	 * @dev gets flightInsuranceCapAmount
	 */
	function getFlightInsuranceCapAmount() external view requireAuthorizeCaller returns (uint256) {
		return flightInsuranceCapAmount;
	}

	/**
	 * @dev checks if flightKey exists or not i.e check if flight is registered
	 */
	function isFlightExists(bytes32 flightKey) external view requireAuthorizeCaller returns (bool) {
		return flights[flightKey].isRegistered;
	}

	// /**
	//  * @dev get registered flights. will be used to show on dapp
	//  */
	// function getRegisteredFlights() external view requireAuthorizeCaller returns (bool) {
	// 	//	return flights[flightKey].isRegistered;
	// 	return true;
	// }

	/**
	 * @dev Sets registeredAppAddress app contract address
	 *
	 * this allow only registeredAppAddress to call data contract
	 */
	function authorizeCaller(address allowedAddress) public requireContractOwner {
		require(authorizeAppContract != allowedAddress, "New authorizeCaller must be different from existing authorizeCaller");
		authorizeAppContract = allowedAddress;
	}

	/**
	 * @dev dummy method to test if isOperational working or not
	 *
	 *  this is for fullfill setTestingMode test requirements
	 */
	function setTestingMode(bool value) public view requireIsOperational {
		value = false; //to remove turffle compile warning.
	}

	/********************************************************************************************/
	/*                                     APP DATA HELPER FUNCTIONS                             */
	/********************************************************************************************/

	/**
	 * @dev method to check if airline already registered or not. called from app contract
	 */
	function isAirlineExists(address airlineAddress) external view requireAuthorizeCaller returns (bool) {
		return registeredAirlinesMap[airlineAddress].isRegistered;
	}

	/**
	 * @dev method to check if airline already registered or not. called from app contract
	 */
	function hasAirlineFunded(address airlineAddress) external view requireAuthorizeCaller returns (bool) {
		return registeredAirlinesMap[airlineAddress].hasFunded;
	}

	/**
	 * @dev method to check if airline already registered or not. called from app contract
	 */
	function getRegisteredAirlineArr() external view requireAuthorizeCaller returns (address[] memory) {
		return registeredAirlineArray;
	}

	/**
	 * @dev adding new airline into the waiting pool of voting approval.
	 * if newAirlineToBeRegistrered wants to be added, 50% vote must be gained by registered & funded voters
	 */
	function addToNewAirlineVotePool(address newAirlineToBeRegistrered, address msgSenderAddress) external requireAuthorizeCaller {
		addressToVoteCountMapping[newAirlineToBeRegistrered][msgSenderAddress] = true;
		pendingAirlineMapping[newAirlineToBeRegistrered].push(msgSenderAddress);
	}

	/**
	 * this methods return true if msgSenderAddress added newAirlineToBeRegistrered address in pending registration pool and msgSenderAddress has funded too.
	 *  it can be said that if true, this mean msgSenderAddress has given his vote in newAirlineToBeRegistrered favour
	 */
	function addedToPoolAndHasFunded(address pendingRegistration, address msgSenderAddress) external view requireAuthorizeCaller returns (bool) {
		return (registeredAirlinesMap[msgSenderAddress].hasFunded && addressToVoteCountMapping[pendingRegistration][msgSenderAddress]);
	}

	/**
	 * @dev get number of votes for the airline which is pending its registration due to not enough voteshare.
	 * registeredAirline : this is the address of airline which has already been registered
	 * pendingAirline : this is the address of airline which is pending registration
	 * Returns :
	 */
	function isAirlinInForRegistration(address pendingAirline, address registeredAirline) external view requireAuthorizeCaller returns (bool) {
		return addressToVoteCountMapping[pendingAirline][registeredAirline];
	}

	/**
	 * pendingAirline has got enough vote to be included in registered flight.
	 * this function removes it from addressToVoteCountMapping pool.
	 */
	function deletePendingAirlineFromPool(address pendingAirline) external requireAuthorizeCaller {
		for (uint256 i = 0; i < pendingAirlineMapping[pendingAirline].length; i++) {
			//deleting all mapping for pendingAirline, becuase it is now registered.
			delete addressToVoteCountMapping[pendingAirline][pendingAirlineMapping[pendingAirline][i]];
		}
		//now delete the array itself.solidity allow this delete from mapping
		delete pendingAirlineMapping[pendingAirline];
	}

	/**
	 * get user balance
	 */
	function getUserBalance(address userAddress) external view requireAuthorizeCaller returns (uint256) {
		return userWallet[userAddress];
	}

	/********************************************************************************************/
	/*                                     SMART CONTRACT FUNCTIONS                             */
	/********************************************************************************************/

	/**
	 * @dev Add an airline to the registration queue
	 *      Can only be called from FlightSuretyApp contract
	 *     no need to check if requireIsOperational, app data will check it, just check requireAuthorizeCaller
	 */
	function registerAirline(address airlineAddress, string name) external requireAuthorizeCaller {
		//just register Airline. no need validation. the logic will be applied in app contract.
		registeredAirlineArray.push(airlineAddress);
		registeredAirlinesMap[airlineAddress] = Airline(name, true, false);
	}

	/**
	 * @dev Buy insurance for a flight
	 *  no validation needed, validation done by app contract
	 */
	function buy(bytes32 flightKey, address userAddress) external payable requireAuthorizeCaller {
		require(msg.value > 0 && msg.value <= flightInsuranceCapAmount, "invalid amount given for insurance buying");
		boughtInsurance[flightKey].insuredPassengers.push(userAddress);
		boughtInsurance[flightKey].insuredAmountMapping[userAddress] = msg.value;
	}

	/**
	 *  @dev Credits payouts to insurees
	 * do not pay directly, just credit users wallet
	 */
	function creditInsurees(bytes32 flightKey) external requireAuthorizeCaller {
		require(boughtInsurance[flightKey].isInsured, "You have not insured yourself");
		address[] memory insuredPeopleArr = boughtInsurance[flightKey].insuredPassengers;
		for (uint256 i = 0; i < insuredPeopleArr.length; i++) {
			uint256 amountToCredit = boughtInsurance[flightKey].insuredAmountMapping[insuredPeopleArr[i]].mul(3).div(2); //credit 1.5 times, can be made configurable
			// debit before credit
			boughtInsurance[flightKey].insuredAmountMapping[insuredPeopleArr[i]] = 0;
			//now credit user wallet.
			userWallet[insuredPeopleArr[i]] = userWallet[insuredPeopleArr[i]] + amountToCredit;
			emit WalletCredited(
				insuredPeopleArr[i],
				amountToCredit,
				string(abi.encodePacked("Insuracne amount credited to your wallet for flight no. ", flights[flightKey].name))
			);
		}

		//delete references
		if (insuredPeopleArr.length > 0) {
			//dIs
			for (uint256 k = 0; k < insuredPeopleArr.length; k++) {
				delete boughtInsurance[flightKey].insuredAmountMapping[insuredPeopleArr[k]];
			}
			//delete array now
			delete boughtInsurance[flightKey].insuredPassengers;
		}
		//delete paidPlayers;
	}

	/**
	 *  @dev Transfers eligible payout funds to insuree
	 *
	 */
	function pay(address userAddress) external requireAuthorizeCaller {
		uint256 userBalance = userWallet[userAddress];
		require(userBalance > 0, "User balance is nil");
		// debit before credit
		delete userWallet[userAddress];
		//now credit user wallet.
		userAddress.transfer(userBalance);
		emit AmountTransferedToUser(userAddress, userBalance);
	}

	/**
	 * @dev Initial funding for the insurance. Unless there are too many delayed flights
	 *      resulting in insurance payouts, the contract should be self-sustaining
	 */
	function fund(address senderAddress) external payable requireAuthorizeCaller {
		if (msg.value == airlineInitialFundAmount) registeredAirlinesMap[senderAddress].hasFunded = true;
	}

	function getFlightKey(
		address airline,
		string memory flight,
		uint256 timestamp
	) internal pure returns (bytes32) {
		return keccak256(abi.encodePacked(airline, flight, timestamp));
	}

	/**
	 * register flight, this data will be used to show in client app
	 */
	function registerFlight(
		address airline,
		string flight,
		uint256 timestamp
	) external requireAuthorizeCaller {
		bytes32 flightKey = getFlightKey(airline, flight, timestamp);
		flights[flightKey] = Flight(true, STATUS_CODE_ON_TIME, timestamp, airline, flight);
		flightsKeyArr.push(flightKey);
	}

	/**
	 * @dev Fallback function for funding smart contract.
	 *
	 */
	function() external payable {
		this.fund(msg.sender);
	}
}
