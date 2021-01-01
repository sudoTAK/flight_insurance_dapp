pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
	using SafeMath for uint256;

	/********************************************************************************************/
	/*                                       DATA VARIABLES                                     */
	/********************************************************************************************/

	address private contractOwner; // Account used to deploy contract
	bool private operational = true; // Blocks all state changes throughout the contract if false
	address private authorizeAppContract; // Account allowed to access this contract

	mapping(address => Airline) private registeredAirlinesMap;
	address[] private registeredAirlineArray = new address[](0);

	struct Airline {
		string name;
		bool isRegistered;
		bool hasFunded;
	}

	/********************************************************************************************/
	/*                                       EVENT DEFINITIONS                                  */
	/********************************************************************************************/

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
	 *
	 */
	function buy() external payable {}

	/**
	 *  @dev Credits payouts to insurees
	 */
	function creditInsurees() external pure {}

	/**
	 *  @dev Transfers eligible payout funds to insuree
	 *
	 */
	function pay() external pure {}

	/**
	 * @dev Initial funding for the insurance. Unless there are too many delayed flights
	 *      resulting in insurance payouts, the contract should be self-sustaining
	 *
	 */
	function fund() public payable {}

	function getFlightKey(
		address airline,
		string memory flight,
		uint256 timestamp
	) internal pure returns (bytes32) {
		return keccak256(abi.encodePacked(airline, flight, timestamp));
	}

	/**
	 * @dev Fallback function for funding smart contract.
	 *
	 */
	function() external payable {
		fund();
	}
}
