pragma solidity ^0.4.0;

contract Market {

    address owner;
    uint bid_counter;
    uint ask_counter;
    uint bid_current;
    uint ask_current;
    uint filled_counter;

    event UnfilledUpdated(string message, uint price, uint contract_number);
    event OrderPartiallyFilled(string message, Order order, uint numberFilled, uint filledCounter);
    event OrderCompletelyFilled(string message, Order order, uint filledCounter);

    struct Order {
        address origin;
        uint price;
        uint contracts;
    }

    function Market() public {
        owner = msg.sender;
        bid_counter = 0;
        ask_counter = 0;
        bid_current = 0;
        ask_current = 0;
        filled_counter = 0;
    }

    mapping(uint=>Order) public asks; //These are yet to be filled
    mapping(uint=>Order) public bids;

    mapping(uint=>Order) public filledBids; //These are filled
    mapping(uint=>Order) public filledAsks;

    function addAsk(address originator, uint _givenPrice, uint _givenContracts) public zeroCheck(_givenPrice) {
        uint bid_check = (_givenPrice*1000000) + bid_current;
        if(bids[bid_check].contracts != 0) {
            fillBid(Order(originator, _givenPrice, _givenContracts), bid_check);
            UnfilledUpdated("Bids are being filled", _givenPrice, _givenContracts);
        } else {
            uint holder = (_givenPrice*1000000) + ask_counter;        //this means there can only be 999,999 orders
            asks[holder] = Order(0xca35b7d915458ef540ade6068dfe2f44e8fa733c, _givenPrice, _givenContracts);
            ask_counter++;
            UnfilledUpdated("Ask contracts were added", _givenPrice, _givenContracts);
        }
    }

    function addBid(address originator, uint _givenPrice, uint _givenContracts) public zeroCheck(_givenPrice) {
        uint ask_check = (_givenPrice*1000000) + ask_current;
        if(asks[ask_check].contracts != 0) {
            fillAsk(Order(originator, _givenPrice, _givenContracts), ask_check);
            UnfilledUpdated("Asks are being filled", _givenPrice, _givenContracts);
        } else {
            uint holder = (_givenPrice*1000000) + bid_counter;        //this means there can only be 999,999 orders
            bids[holder] = Order(0xca35b7d915458ef540ade6068dfe2f44e8fa733c, _givenPrice, _givenContracts);
            bid_counter++;
            UnfilledUpdated("Bid contracts were added", _givenPrice, _givenContracts);
        }
    }

// Send an ask to this and:
// 1. If there is nothing left to fill it, a new unfilled is created.
// 2. If it is bigger than the thing it is filling, it moves to the next order to be filled.
// 3. If the order to be filled is larger than it, it just fills completely and the order to be filled has x less contracts.

    function fillAsk(Order filling_order, uint ask_check) public {
        if(asks[ask_check].contracts == 0) {
            addAsk(filling_order.origin, filling_order.price, filling_order.contracts);
        } if(asks[ask_check].contracts <= filling_order.contracts) {
            ask_current++;
            filling_order.contracts -= asks[ask_check].contracts;
            filledAsks[filled_counter] = asks[ask_check];
            filledBids[filled_counter] = Order(filling_order.origin, filling_order.price, asks[ask_check].contracts);
            OrderPartiallyFilled("Order was partially filled", filling_order, asks[ask_check].contracts, filled_counter);

            filled_counter++;
            fillAsk(filling_order, ask_check+1);
        } else {
            asks[ask_check].contracts -= filling_order.contracts;
            filledBids[filled_counter] = filling_order;
            filledAsks[filled_counter] = Order(asks[ask_check].origin, asks[ask_check].price, filling_order.contracts);
            OrderCompletelyFilled("The order was completely filled", filling_order, filled_counter);  //I'm also going to have to fit in the filled counter with how I alert the user

            filled_counter++;
        }
    }

    function fillBid(Order filling_order, uint bid_check) public {
        if(bids[bid_check].contracts == 0) {
            addAsk(filling_order.origin, filling_order.price, filling_order.contracts);
        } if(bids[bid_check].contracts <= filling_order.contracts) {  //as well as a fillAsk function
            bid_current++;
            filling_order.contracts -= bids[bid_check].contracts;
            filledBids[filled_counter] = bids[bid_check];
            filledAsks[filled_counter] = Order(filling_order.origin, filling_order.price, bids[bid_check].contracts);
            OrderPartiallyFilled("Order was partially filled", filling_order, bids[bid_check].contracts, filled_counter);

            filled_counter++;
            fillBid(filling_order, bid_check+1);
        } else {
            bids[bid_check].contracts -= filling_order.contracts;
            filledAsks[filled_counter] = filling_order;
            filledBids[filled_counter] = Order(bids[bid_check].origin, bids[bid_check].price, filling_order.contracts);
            OrderCompletelyFilled("The order was completely filled", filling_order, filled_counter);  //I'm also going to have to fit in the filled counter with how I alert the user

            filled_counter++;
        }
    }

    modifier zeroCheck(uint testing) {
        require(testing > 0 && testing < 10000);
        _;
    }

}

// The user has to know what outstanding orders they have and what filled orders they have.
// This will have to be done via notifications from the market.

contract User {

    address owner;
    uint balance;

    event InvalidOrder(string message, uint price, uint contract_number);
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier checkOrder(uint _givenPrice, uint _givenContracts) {
        if(_givenPrice >= 1000 || _givenPrice <= 0 || _givenContracts <= 0) {
            InvalidOrder('The price or contracts were out of bounds', _givenPrice, _givenContracts);
            require(_givenPrice < 1000 && _givenPrice > 0 && _givenContracts > 0);
        }
        _;
    }

    // User stuff
    function User() public {
        owner = msg.sender;
    }

    function() payable public {
        balance += msg.value;
    }

    function deposit() payable public {
        balance += msg.value;
    }

    function getBalance() onlyOwner constant public returns(uint){
        return(this.balance);
    }

}
