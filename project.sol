// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract P2PShippingPlatform {

    enum ShippingStatus { Pending, InTransit, Delivered, Completed }

    struct Shipment {
        uint256 id;
        address requester;
        address carrier;
        string description;
        uint256 payment;
        ShippingStatus status;
        bool isConfirmedByRequester;
        bool isConfirmedByCarrier;
    }

    uint256 public shipmentCounter;
    mapping(uint256 => Shipment) public shipments;

    event ShipmentCreated(uint256 shipmentId, address requester, address carrier, uint256 payment);
    event ShipmentUpdated(uint256 shipmentId, ShippingStatus status);
    event ShipmentConfirmed(uint256 shipmentId, address confirmer);
    event PaymentReleased(uint256 shipmentId, address carrier, uint256 payment);

    modifier onlyRequester(uint256 _shipmentId) {
        require(msg.sender == shipments[_shipmentId].requester, "Only the requester can perform this action");
        _;
    }

    modifier onlyCarrier(uint256 _shipmentId) {
        require(msg.sender == shipments[_shipmentId].carrier, "Only the carrier can perform this action");
        _;
    }

    modifier shipmentExists(uint256 _shipmentId) {
        require(shipments[_shipmentId].id != 0, "Shipment does not exist");
        _;
    }

    modifier notDelivered(uint256 _shipmentId) {
        require(shipments[_shipmentId].status != ShippingStatus.Delivered, "Shipment already delivered");
        _;
    }

    modifier shipmentPendingConfirmation(uint256 _shipmentId) {
        require(
            shipments[_shipmentId].isConfirmedByRequester && shipments[_shipmentId].isConfirmedByCarrier,
            "Shipment must be confirmed by both parties"
        );
        _;
    }

    // Create a shipment request
    function createShipment(address _carrier, string memory _description) external payable {
        require(msg.value > 0, "Payment must be greater than 0");

        shipmentCounter++;
        shipments[shipmentCounter] = Shipment({
            id: shipmentCounter,
            requester: msg.sender,
            carrier: _carrier,
            description: _description,
            payment: msg.value,
            status: ShippingStatus.Pending,
            isConfirmedByRequester: false,
            isConfirmedByCarrier: false
        });

        emit ShipmentCreated(shipmentCounter, msg.sender, _carrier, msg.value);
    }

    // Confirm the shipment as carrier
    function confirmShipmentAsCarrier(uint256 _shipmentId) external onlyCarrier(_shipmentId) shipmentExists(_shipmentId) notDelivered(_shipmentId) {
        Shipment storage shipment = shipments[_shipmentId];
        shipment.isConfirmedByCarrier = true;

        emit ShipmentConfirmed(_shipmentId, msg.sender);
    }

    // Confirm the shipment as requester
    function confirmShipmentAsRequester(uint256 _shipmentId) external onlyRequester(_shipmentId) shipmentExists(_shipmentId) notDelivered(_shipmentId) {
        Shipment storage shipment = shipments[_shipmentId];
        shipment.isConfirmedByRequester = true;

        emit ShipmentConfirmed(_shipmentId, msg.sender);
    }

    // Mark the shipment as delivered
    function markAsDelivered(uint256 _shipmentId) external shipmentExists(_shipmentId) shipmentPendingConfirmation(_shipmentId) {
        Shipment storage shipment = shipments[_shipmentId];
        shipment.status = ShippingStatus.Delivered;

        emit ShipmentUpdated(_shipmentId, ShippingStatus.Delivered);
    }

    // Release payment to the carrier after delivery confirmation
    function releasePayment(uint256 _shipmentId) external shipmentExists(_shipmentId) shipmentPendingConfirmation(_shipmentId) {
        Shipment storage shipment = shipments[_shipmentId];
        
        // Release payment to carrier
        payable(shipment.carrier).transfer(shipment.payment);

        // Update shipment status to completed
        shipment.status = ShippingStatus.Completed;

        emit PaymentReleased(_shipmentId, shipment.carrier, shipment.payment);
    }

    // View shipment details
    function getShipmentDetails(uint256 _shipmentId) external view returns (Shipment memory) {
        return shipments[_shipmentId];
    }
}
