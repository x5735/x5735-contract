/**
 *Submitted for verification at BscScan.com on 2023-03-26
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

        contract FreelanceContract {
        struct Order {
        address payable customer;
        string description;
        string fullDescription;
        string category;
        uint256 price;
        address payable executor;
        bool completed;
        bool accepted;
        bool paid;
        address payable assignedExecutor;
        string ipfsHash;
    }
        mapping(uint256 => Order) public orders;
        mapping(uint256 => uint256) public escrowBalances;
        uint256 public orderIndex;
        address public owner;

        event OrderCreated(address customer, uint256 orderId);
        event PersonalOrderCreated(address customer, uint256 orderId, address assignedExecutor);
        event OrderAccepted(uint256 orderId);
        event OrderCompleted(uint256 orderId);
        event OrderCancelled(uint256 orderId);
        event OrderPaid(uint256 orderId, uint256 amount);
        event OrderEdited(uint256 orderId);
        event IpfsHashSet(uint256 orderId, string ipfsHash);

    constructor() {
        owner = msg.sender;
    }

    function createOrder(
        string memory description,
        string memory fullDescription,
        string memory category,
        uint256 price,
        address payable assignedExecutor
    ) public {
    require(price > 0, "Price must be greater than zero");
    orderIndex++;
    orders[orderIndex] = Order(
        payable(msg.sender),
        description,
        fullDescription,
        category,
        price,
        payable(address(0)),
        false,
        false,
        false,
        assignedExecutor,
        ""
    );
    
        if (assignedExecutor != address(0)) {
            emit PersonalOrderCreated(msg.sender, orderIndex, assignedExecutor);
        } else {
            emit OrderCreated(msg.sender, orderIndex);
        }
    }

    function getOrders() public view returns (Order[] memory) {
        Order[] memory result = new Order[](orderIndex);
        for (uint256 i = 1; i <= orderIndex; i++) {
            result[i - 1] = orders[i];
        }
        return result;
    }

    function takeOrder(uint256 orderId) public {
        Order storage order = orders[orderId];
        require(!order.completed, "Order is completed");
        require(!order.accepted, "Order is already accepted");
        require(order.assignedExecutor == address(0), "Order is a personal order");
        order.executor = payable(msg.sender);
        order.accepted = true;
        emit OrderAccepted(orderId);
    }

    function acceptPersonalOrder(uint256 orderId) public {
        Order storage order = orders[orderId];
        require(!order.completed, "Order is completed");
        require(!order.accepted, "Order is already accepted");
        require(msg.sender == order.assignedExecutor, "Only assigned executor can accept personal order");
        order.executor = payable(msg.sender);
        order.accepted = true;
        emit OrderAccepted(orderId);
    }

    function completeOrder(uint256 orderId) public {
        Order storage order = orders[orderId];
        require(order.accepted, "Order is not accepted");
        require(msg.sender == order.executor, "Only executor can complete order");
        require(!order.completed, "Order is already completed");
        order.completed = true;
        order.paid = true;
        emit OrderCompleted(orderId);
        uint256 escrowAmount = escrowBalances[orderId];
        require(escrowAmount > 0, "No funds in escrow");
        order.executor.transfer(escrowAmount);
        escrowBalances[orderId] = 0;
    }

    function cancelOrder(uint256 orderId) public {
        Order storage order = orders[orderId];
        require(!order.completed, "Order is completed");
        require(msg.sender == order.customer, "Only customer can cancel order");
        order.completed = true;
        payable(msg.sender).transfer(escrowBalances[orderId]);
        escrowBalances[orderId] = 0;
        emit OrderCancelled(orderId);
    }

    function payOrder(uint256 orderId) public payable {
        Order storage order = orders[orderId];
        require(order.accepted, "Order is not accepted");
        require(!order.completed, "Order is already completed");
        require(msg.sender == order.customer, "Only customer can pay for order");
        require(msg.value >= order.price, "Insufficient payment amount");

        escrowBalances[orderId] = msg.value;
        order.paid = true;
        emit OrderPaid(orderId, msg.value);
    }

    function editOrder(uint256 orderId, string memory fullDescription) public {
        Order storage order = orders[orderId];
        require(!order.accepted, "Order is already accepted");
        require(msg.sender == order.customer, "Only customer can edit order");
        order.fullDescription = fullDescription;
        emit OrderEdited(orderId);
    }

    function setIpfsHash(uint256 orderId, string memory ipfsHash) public {
        require(msg.sender == owner, "Only contract owner can set IPFS hash");
        orders[orderId].ipfsHash = ipfsHash;
        emit IpfsHashSet(orderId, ipfsHash);
    }

    function balanceOf(address user) public view returns (uint256) {
        return address(user).balance;
    }

    function withdraw(uint256 amount) public {
        require(amount <= address(this).balance, "Insufficient contract balance");
        require(msg.sender == owner, "Only contract owner can withdraw funds");
        payable(msg.sender).transfer(amount);
    }
}