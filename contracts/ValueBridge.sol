// SPDX-License-Identifier: MIT
pragma solidity > 0.8.11 <= 0.8.14;

/**
@title Value Bridge
@author Devvie
@notice This contract will serve as a bridge by which values (ethers, nft, tokens) are sent to the
owner, and also as a value safe-vault for the owner's received values. 
It simply imposes a minimum amount transferrable to the owner, and the minimum amount withdrawable by the owner.
@dev This contract accepts values (ethers, nft, tokens) on-behalf of the owner, imposing a minimum amount of transfer and withdrawal.
*/
contract ValueBridge {
     /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
    @notice This represents info for payment to the owner 
    @dev Structure for payments
    */
    struct Sender {
        uint amount;
        string note;
    }

    /**
    @notice This will hold the info about transfers to the owner through this bridge
    @dev A mapping from addresses making transfers to transfer info
    */
    mapping(address => Sender[]) public transfers;

    /// @dev Deployer's address (EOA or contract)
    /// @notice The address of the owner/deployer of the smart contract
    address payable immutable public owner;

    /// @dev Deployer's address
    /// @notice The address of the owner/deployer of the smart contract
    string public ownerName;

    /// @dev Minimum transferrable amount in wei, to be set by owner
    /// @notice Minimum amount to transfer to owner of contract 
    uint public immutable minTransferAmt;

    /// @dev Minimum withdrawal amount in wei, to be set by owner
    /// @notice Minimum amount that can be withdrawn from the contract by the owner of contract 
    uint public immutable minWithdrawAmt;

    /// @notice This event will be emitted whenever value is sent to this contract
    /// @dev Event for when value is received
    /// @param _senderAddress Wallet address of the sender
    /// @param _sentAmt Amount of ether (in Wei) received from sender
    event ValueReceived(address indexed _senderAddress, uint indexed _sentAmt);

    /// @notice This event will be emitted whenever value is withdrawn by owner of contract
    /// @dev Event for when value is withdrawn by owner
    /// @param _withdrawnAmt Amount of ether (in Wei) received from sender
    event ValueWithdrawn(uint indexed _withdrawnAmt);

    /// @notice This modifier makes parts of the contract only accessible by owner
    /// @dev Makes functions only callable by owner
    modifier OnlyOwner {
        require(msg.sender == owner, string.concat("Sorry! only ", ownerName ," can call this function"));
        _;
    }

    /// @notice This modifier ensures transferred values reach the minimum required
    /// @dev Ensures transferred values are up to minimum
    modifier UpToMinimum {
        require(
            msg.value >= minTransferAmt, 
            string.concat("Sorry! you can only transfer ", toString(minTransferAmt), " Wei or more to ", ownerName)
        );
        _;
    }

    /// @notice This modifier ensures owner doesn't withdraw below minimum amount
    /// @dev Ensures owner doesn't withdraw below the minimum withdrawable
    modifier BalanceEnoughForWithdrawal {
        require(
            address(this).balance >= minWithdrawAmt, 
            string.concat("Sorry! ", ownerName, " You can only withdraw when balance is up to ", toString(minWithdrawAmt), " Wei or more")
        );
        _;
    }

    constructor(string memory _ownerName, uint _minTransferAmt, uint _minWithdrawAmt){
        owner = payable(msg.sender); // set owner address
        ownerName = _ownerName; // set owner name
        minTransferAmt = _minTransferAmt; // set's minimum transfer
        minWithdrawAmt = _minWithdrawAmt; // set's minimum withdraw
    }

    /// @notice This function will be called to send values to contract owner
    /// @notice Sending values directly to the contract still works but won't be recorded
    /// @dev Called to send values to contract owner
    /// @param _note An optional note describing purpose of transfer
    function transfer(string calldata _note) UpToMinimum external payable {
        // Let's store the info
        transfers[msg.sender].push(Sender(msg.value, _note));
        // Let's emit the event
        emit ValueReceived(msg.sender, msg.value);

        /// @dev As gas optimisation, if sent ether is 0, let's not waste gas calling transfer
        if(msg.value == 0) return;
        // We would have just shared any sent ether between the owner and contract equally
        // but because we can't store decimal values, we might get a decimal result if we try to
        // divide sent ether into two.
        // The solution will be to send equal amounts to both parties if the sent ether is even
        // But if not even, we'll send 60% to the owner and keep 40% in the contract
        if((msg.value % 2) == 0){
            // Let's send 50% of what was sent to the owner
            owner.transfer(msg.value/2);
        } else {
            // Since the sent amount is not even, lets send 60% of it to the owner.
            // E.g if someone sends 3 ethers, we'll add 1 to it then divide to get 2 ethers, this 2 ethers will
            // be sent to owner, and the contract holds 1. However if 1 ether is sent, owner gets nothing, contract keeps all
            owner.transfer((msg.value+1) / 2);
        }
    }

    /// @dev This will be called by owner to withdraw funds from the contract
    /// @notice This will be called by owner to withdraw funds from the contract
    function withdraw(uint _withdrawAmt) OnlyOwner BalanceEnoughForWithdrawal external {
        // assert for zero value withdrawal
        assert(_withdrawAmt != 0);

        emit ValueWithdrawn(_withdrawAmt);
        // we give owner all funds if he requests over what he/she has
        if(_withdrawAmt > address(this).balance){
            owner.transfer(address(this).balance);
        } else {
            owner.transfer(_withdrawAmt);
        }

    }

    /// @notice This will handle sending ether directly to the contract
    /// @dev This will impose minimum transfer rule for plain ether transfer
    receive() external payable {
        // We're not using UpToMinimum modifier because it'll exhaust all available gas
        // instead we implement a minimal check
        require(
            msg.value >= minTransferAmt, 
            "Sorry! the transferred amount is too low"
        );

        // we're not storing transfer info because it'll exhaust available gas
        // let's just emit an event
        emit ValueReceived(msg.sender, msg.value);
    }

    /// @notice This will handle calling non-existing function with ether value
    /// @dev This will impose minimum transfer rule for interface confusions
    fallback() external payable {
        // // We're not using UpToMinimum modifier because it'll exhaust all available gas
        // // instead we implement a minimal check
        require(
            msg.value >= minTransferAmt, 
            "Called function doesn't exist and the transferred amount is too low"
        );

        // we're not storing transfer info because it'll exhaust available gas
        // let's just emit an event
        emit ValueReceived(msg.sender, msg.value);
    }
}