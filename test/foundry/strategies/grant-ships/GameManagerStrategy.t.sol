// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import {AlloSetup} from "../../shared/AlloSetup.sol";
import {RegistrySetupFullLive} from "../../shared/RegistrySetup.sol";
import {Metadata} from "../../../../contracts/core/libraries/Metadata.sol";
import {Errors} from "../../../../contracts/core/libraries/Errors.sol";
import {EventSetup} from "../../shared/EventSetup.sol";
import {GameManagerStrategy} from "../../../../contracts/strategies/_poc/grant-ships/GameManagerStrategy.sol";
import {GameManagerSetup} from "./GameManagerSetup.t.sol";
import {GrantShipStrategy} from "./GrantShipStrategy.t.sol";

import {IStrategy} from "../../../../contracts/core/interfaces/IStrategy.sol";
import {ShipInitData} from "../../../../contracts/strategies/_poc/grant-ships/libraries/GrantShipShared.sol";

contract GameManagerStrategyTest is Test, GameManagerSetup, Errors, EventSetup {
    /// ===============================
    /// ========== Events =============
    /// ===============================

    event RoundCreated(uint256 gameIndex, address token, uint256 totalRoundAmount);
    event ApplicationRejected(address recipientAddress);
    event ShipLaunched(
        address shipAddress, uint256 shipPoolId, address applicantId, string shipName, Metadata metadata
    );

    /// ===============================
    /// ========== State ==============
    /// ===============================

    uint256 internal constant _3_MONTHS = 7889400;
    uint256 internal constant _GAME_AMOUNT = 90_000e18;
    uint256 internal constant _SHIP_AMOUNT = 30_000e18;

    GrantShipStrategy internal ship;
    GrantShipStrategy internal ship2;
    GrantShipStrategy internal ship3;

    function setUp() public {
        vm.createSelectFork({blockNumber: 166_807_779, urlOrAlias: "arbitrumOne"});

        __ManagerSetup();
    }

    // ====================================
    // =========== Tests ==================
    // ====================================

    function test_registerRecipient() public {
        address recipientId = _register_recipient();

        GameManagerStrategy.Recipient memory recipient = gameManager().getRecipient(recipientId);
        bytes32 profileId = registry().getProfileByAnchor(profile1_anchor()).id;

        // Check that the recipient was registered
        assertEq(recipient.recipientAddress, profile1_anchor());
        assertEq(recipient.profileId, profileId);
        assertEq(recipient.shipName, "Ship Name");
        assertEq(recipient.shipAddress, address(0));
        assertEq(recipient.previousAddress, address(0));
        assertEq(recipient.shipPoolId, 0);
        assertEq(recipient.grantAmount, 0);
        assertEq(recipient.metadata.pointer, "Ship 1");
        assertEq(recipient.metadata.protocol, 1);
        assertEq(uint8(recipient.status), uint8(IStrategy.Status.Pending));
    }

    function testRevert_registerRecipient_UNAUTHORIZED() public {
        address recipientId = profile1_anchor();

        Metadata memory metadata = Metadata(1, "Ship 1");

        bytes memory data = abi.encode(recipientId, "Ship Name", metadata);

        uint256 poolId = gameManager().getPoolId();
        address rando = randomAddress();

        vm.expectRevert(UNAUTHORIZED.selector);
        vm.startPrank(rando);
        allo().registerRecipient(poolId, data);
        vm.stopPrank();
    }

    function testRevert_registerRecipient_INVALID_METADATA() public {
        address recipientId = profile1_anchor();

        Metadata memory badMetadata = Metadata(1, "");

        bytes memory data = abi.encode(recipientId, "Ship Name", badMetadata);

        uint256 poolId = gameManager().getPoolId();

        vm.expectRevert(INVALID_METADATA.selector);
        vm.startPrank(profile1_member1());
        allo().registerRecipient(poolId, data);
        vm.stopPrank();
    }

    function test_registerRecipient_UpdateApplication() public {
        address recipientId = _register_recipient();

        bytes32 profileId = registry().getProfileByAnchor(profile1_anchor()).id;
        GameManagerStrategy.Recipient memory recipient = gameManager().getRecipient(recipientId);

        assertEq(recipient.recipientAddress, profile1_anchor());
        assertEq(recipient.profileId, profileId);
        assertEq(recipient.shipName, "Ship Name");
        assertEq(recipient.shipAddress, address(0));
        assertEq(recipient.previousAddress, address(0));
        assertEq(recipient.shipPoolId, 0);
        assertEq(recipient.grantAmount, 0);
        assertEq(recipient.metadata.pointer, "Ship 1");
        assertEq(recipient.metadata.protocol, 1);
        assertEq(uint8(recipient.status), uint8(IStrategy.Status.Pending));

        Metadata memory metadata = Metadata(1, "Ship 1: Part 2");

        bytes memory data = abi.encode(recipientId, "Ship Name: Part 2", metadata);

        uint256 poolId = gameManager().getPoolId();

        vm.startPrank(profile1_member1());
        allo().registerRecipient(poolId, data);
        vm.stopPrank();

        GameManagerStrategy.Recipient memory newRecipient = gameManager().getRecipient(recipientId);

        assertEq(newRecipient.recipientAddress, profile1_anchor());
        assertEq(newRecipient.profileId, profileId);
        assertEq(newRecipient.shipName, "Ship Name: Part 2");
        assertEq(newRecipient.shipAddress, address(0));
        assertEq(newRecipient.previousAddress, address(0));
        assertEq(newRecipient.shipPoolId, 0);
        assertEq(newRecipient.grantAmount, 0);
        assertEq(newRecipient.metadata.pointer, "Ship 1: Part 2");
        assertEq(newRecipient.metadata.protocol, 1);
        assertEq(uint8(newRecipient.status), uint8(IStrategy.Status.Pending));
    }

    function test_createRound() public {
        _register_create_round();

        GameManagerStrategy.GameRound memory round = gameManager().getGameRound(0);

        assertEq(_GAME_AMOUNT, round.totalRoundAmount);
        assertEq(address(ARB()), round.token);
        assertEq(uint8(round.roundStatus), uint8(GameManagerStrategy.RoundStatus.Pending));
        assertEq(uint8(round.startTime), 0);
        assertEq(uint8(round.endTime), 0);
        assertEq(round.ships.length, 0);
    }

    function testRevert_createRound_UNAUTHORIZED() public {
        _register_create_round();

        vm.expectRevert(UNAUTHORIZED.selector);
        vm.startPrank(randomAddress());
        gameManager().createRound(_GAME_AMOUNT, address(ARB()));
        vm.stopPrank();
    }

    function testRevert_createRound_INVALID_STATUS() public {
        _register_create_round();

        vm.expectRevert(GameManagerStrategy.INVALID_STATUS.selector);

        vm.startPrank(facilitator().wearer);
        gameManager().createRound(_GAME_AMOUNT, address(ARB()));
        vm.stopPrank();
    }

    function test_reviewApplicant_approve() public {
        address recipientAddress = _register_create_approve();

        GameManagerStrategy.Recipient memory recipient = gameManager().getRecipient(recipientAddress);

        assertEq(recipient.recipientAddress, recipientAddress);
        assertEq(recipient.profileId, registry().getProfileByAnchor(profile1_anchor()).id);
        assertEq(recipient.shipName, "Ship Name");
        assertEq(recipient.shipAddress, address(ship));
        assertEq(recipient.previousAddress, address(0));
        assertEq(recipient.shipPoolId, ship.getPoolId());
        assertEq(recipient.grantAmount, 0);
        assertEq(recipient.metadata.pointer, "Ship 1");
        assertEq(recipient.metadata.protocol, 1);
        assertEq(uint8(recipient.status), uint8(GameManagerStrategy.ShipStatus.Accepted));
    }

    function testRevert_reviewApplicant_INVALID_STATUS() public {
        address applicantId = _register_create_round();

        address[] memory contractAsManager = new address[](1);
        contractAsManager[0] = address(gameManager());
        bytes32 profileId = registry().getProfileByAnchor(profile1_anchor()).id;

        vm.startPrank(profile1_owner());
        registry().addMembers(profileId, contractAsManager);
        vm.stopPrank();

        vm.expectRevert(GameManagerStrategy.INVALID_STATUS.selector);

        vm.startPrank(facilitator().wearer);
        gameManager().reviewRecipient(
            applicantId,
            GameManagerStrategy.ShipStatus.None,
            ShipInitData(true, true, true, "Ship Name", Metadata(1, "Ship 1"), team(0).wearer, shipOperator(0).id)
        );
        vm.stopPrank();
    }

    function test_reviewApplicant_reject() public {
        address recipientAddress = _register_create_reject();

        GameManagerStrategy.Recipient memory recipient = gameManager().getRecipient(recipientAddress);

        assertEq(recipient.recipientAddress, recipientAddress);
        assertEq(recipient.profileId, registry().getProfileByAnchor(profile1_anchor()).id);
        assertEq(recipient.shipName, "Ship Name");
        assertEq(recipient.shipAddress, address(0));
        assertEq(recipient.previousAddress, address(0));
        assertEq(recipient.shipPoolId, 0);
        assertEq(recipient.grantAmount, 0);
        assertEq(recipient.metadata.pointer, "Ship 1");
        assertEq(recipient.metadata.protocol, 1);
        assertEq(uint8(recipient.status), uint8(GameManagerStrategy.ShipStatus.Rejected));
    }

    function test_allocate() public {
        address[] memory recipients = _register_create_accept_allocate();

        address recipientAddress = recipients[0];
        address recipientAddress2 = recipients[1];
        address recipientAddress3 = recipients[2];

        GameManagerStrategy.Recipient memory recipient1 = gameManager().getRecipient(recipientAddress);
        bytes32 profileId1 = registry().getProfileByAnchor(profile1_anchor()).id;

        assertEq(recipient1.recipientAddress, recipientAddress);
        assertEq(recipient1.profileId, profileId1);
        assertEq(recipient1.shipName, "Ship Name");
        assertEq(recipient1.shipAddress, address(ship));
        assertEq(recipient1.previousAddress, address(0));
        assertEq(recipient1.shipPoolId, ship.getPoolId());
        assertEq(recipient1.grantAmount, 20_000e18);
        assertEq(recipient1.metadata.pointer, "Ship 1");
        assertEq(recipient1.metadata.protocol, 1);
        assertEq(uint8(recipient1.status), uint8(GameManagerStrategy.ShipStatus.Allocated));

        GameManagerStrategy.Recipient memory recipient2 = gameManager().getRecipient(recipientAddress2);
        bytes32 profileId2 = registry().getProfileByAnchor(profile2_anchor()).id;

        assertEq(recipient2.recipientAddress, recipientAddress2);
        assertEq(recipient2.profileId, profileId2);
        assertEq(recipient2.shipName, "Ship Name 2");
        assertEq(recipient2.shipAddress, address(ship2));
        assertEq(recipient2.previousAddress, address(0));
        assertEq(recipient2.shipPoolId, ship2.getPoolId());
        assertEq(recipient2.grantAmount, 40_000e18);
        assertEq(recipient2.metadata.pointer, "Ship 2");
        assertEq(recipient2.metadata.protocol, 1);
        assertEq(uint8(recipient2.status), uint8(GameManagerStrategy.ShipStatus.Allocated));

        GameManagerStrategy.Recipient memory recipient3 = gameManager().getRecipient(recipientAddress3);
        bytes32 profileId3 = registry().getProfileByAnchor(poolProfile_anchor()).id;

        assertEq(recipient3.recipientAddress, recipientAddress3);
        assertEq(recipient3.profileId, profileId3);
        assertEq(recipient3.shipName, "Ship Name 3");
        assertEq(recipient3.shipAddress, address(ship3));
        assertEq(recipient3.previousAddress, address(0));
        assertEq(recipient3.shipPoolId, ship3.getPoolId());
        assertEq(recipient3.grantAmount, 30_000e18);
        assertEq(recipient3.metadata.pointer, "Ship 3");
        assertEq(recipient3.metadata.protocol, 1);
        assertEq(uint8(recipient3.status), uint8(GameManagerStrategy.ShipStatus.Allocated));

        GameManagerStrategy.GameRound memory round = gameManager().getGameRound(0);

        address[] memory roundShips = round.ships;

        address roundShip = roundShips[0];
        address roundShip2 = roundShips[1];
        address roundShip3 = roundShips[2];

        assertEq(uint8(round.startTime), 0);
        assertEq(uint8(round.endTime), 0);
        assertEq(_GAME_AMOUNT, round.totalRoundAmount);
        assertEq(address(ARB()), round.token);
        assertEq(uint8(round.roundStatus), uint8(GameManagerStrategy.RoundStatus.Allocated));
        assertEq(roundShips.length, 3);
        assertEq(roundShip, recipientAddress);
        assertEq(roundShip2, recipientAddress2);
        assertEq(roundShip3, recipientAddress3);
    }

    // function testRevert_allocate_INVALID_STATUS() public {
    //     address recipientAddress = _register_create_approve();

    //     address[] memory recipientAddresses = new address[](1);
    //     recipientAddresses[0] = recipientAddress;

    //     uint256[] memory amounts = new uint256[](1);
    //     amounts[0] = 20_000e18;

    //     bytes memory data = abi.encode(recipientAddresses, amounts, _GAME_AMOUNT);

    //     vm.expectRevert(GameManagerStrategy.INVALID_STATUS.selector);

    //     vm.startPrank(facilitator().wearer);
    //     allo().allocate(gameManager().getPoolId(), data);
    //     vm.stopPrank();
    // }

    function testRevert_allocate_NOT_ENOUGH_FUNDS_total() public {
        address recipientAddress = _register_create_approve();
        _quick_fund_manager();

        address[] memory recipientAddresses = new address[](1);
        recipientAddresses[0] = recipientAddress;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = _GAME_AMOUNT;

        bytes memory data = abi.encode(recipientAddresses, amounts, _GAME_AMOUNT + 1);

        uint256 poolId = gameManager().getPoolId();
        vm.expectRevert(NOT_ENOUGH_FUNDS.selector);

        vm.startPrank(facilitator().wearer);
        allo().allocate(poolId, data);
        vm.stopPrank();
    }

    function testRevert_allocate_ARRAY_MISMATCH_out_of_bounds() public {
        address recipientAddress = _register_recipient();
        _quick_fund_manager();

        address[] memory recipientAddresses = new address[](1);
        recipientAddresses[0] = recipientAddress;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = _GAME_AMOUNT;

        bytes memory data = abi.encode(recipientAddresses, amounts, _GAME_AMOUNT);

        uint256 poolId = gameManager().getPoolId();

        vm.expectRevert(ARRAY_MISMATCH.selector);

        vm.startPrank(facilitator().wearer);
        allo().allocate(poolId, data);
        vm.stopPrank();
    }

    function testRevert_allocate_ARRAY_MISMATCH_param_length() public {
        address recipientAddress = _register_create_approve();
        _quick_fund_manager();

        address[] memory recipientAddresses = new address[](1);

        recipientAddresses[0] = recipientAddress;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = _GAME_AMOUNT;
        amounts[1] = _GAME_AMOUNT;

        bytes memory data = abi.encode(recipientAddresses, amounts, _GAME_AMOUNT);

        uint256 poolId = gameManager().getPoolId();

        vm.expectRevert(ARRAY_MISMATCH.selector);

        vm.startPrank(facilitator().wearer);
        allo().allocate(poolId, data);
        vm.stopPrank();
    }

    function testRevert_allocate_NOT_ENOUGH_FUNDS_in_loop() public {
        address recipientAddress = _register_create_approve();
        _quick_fund_manager();

        address[] memory recipientAddresses = new address[](1);
        recipientAddresses[0] = recipientAddress;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = _GAME_AMOUNT + 1;

        bytes memory data = abi.encode(recipientAddresses, amounts, _GAME_AMOUNT);

        uint256 poolId = gameManager().getPoolId();

        vm.expectRevert(NOT_ENOUGH_FUNDS.selector);

        vm.startPrank(facilitator().wearer);
        allo().allocate(poolId, data);
        vm.stopPrank();
    }

    function testRevert_allocate_MISMATCH() public {
        address recipientAddress = _register_create_approve();
        _quick_fund_manager();

        address[] memory recipientAddresses = new address[](1);
        recipientAddresses[0] = recipientAddress;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = _GAME_AMOUNT;

        bytes memory data = abi.encode(recipientAddresses, amounts, _GAME_AMOUNT - 1);

        uint256 poolId = gameManager().getPoolId();

        vm.expectRevert(MISMATCH.selector);

        vm.startPrank(facilitator().wearer);
        allo().allocate(poolId, data);
        vm.stopPrank();
    }

    function test_distribute() public {
        address[] memory recipients = _register_create_accept_allocate_distribute();
    }

    // ====================================
    // =========== Helpers ================
    // ====================================

    function _register_create_accept_allocate_distribute() internal returns (address[] memory recipients) {
        recipients = _register_create_accept_allocate();

        bytes memory data = abi.encode(block.timestamp, block.timestamp + _3_MONTHS);

        uint256 poolId = gameManager().getPoolId();

        vm.expectEmit(true, true, true, true);
        emit Distributed(recipients[0], address(ship), 20_000e18, facilitator().wearer);
        emit Distributed(recipients[1], address(ship2), 40_000e18, facilitator().wearer);
        emit Distributed(recipients[2], address(ship3), 30_000e18, facilitator().wearer);

        vm.startPrank(facilitator().wearer);
        allo().distribute(poolId, recipients, data);
        vm.stopPrank();
    }

    function _register_create_accept_allocate() internal returns (address[] memory) {
        address recipientAddress = _register_create_approve();
        _quick_fund_manager();

        // Register recipient 2
        address recipientAddress2 = profile2_anchor();
        Metadata memory metadata2 = Metadata(1, "Ship 2");
        bytes memory data2 = abi.encode(recipientAddress2, "Ship Name 2", metadata2);
        vm.startPrank(profile2_owner());
        allo().registerRecipient(gameManager().getPoolId(), data2);
        vm.stopPrank();

        // Register reciepient 3
        address recipientAddress3 = poolProfile_anchor();
        Metadata memory metadata3 = Metadata(1, "Ship 3");
        bytes memory data3 = abi.encode(recipientAddress3, "Ship Name 3", metadata3);
        vm.startPrank(pool_admin());
        allo().registerRecipient(gameManager().getPoolId(), data3);
        vm.stopPrank();

        address[] memory contractAsManager = new address[](1);
        contractAsManager[0] = address(gameManager());

        // Review recipient 2
        vm.startPrank(profile2_owner());
        registry().addMembers(profile2_id(), contractAsManager);
        vm.stopPrank();

        vm.startPrank(facilitator().wearer);
        address payable shipAddress2 = gameManager().reviewRecipient(
            profile2_anchor(),
            GameManagerStrategy.ShipStatus.Accepted,
            ShipInitData(true, true, true, "Ship Name 2", Metadata(1, "Ship 2"), team(1).wearer, shipOperator(1).id)
        );
        vm.stopPrank();
        // console.log("got here");
        ship2 = GrantShipStrategy(shipAddress2);

        // Review recipient 3
        vm.startPrank(pool_admin());
        registry().addMembers(poolProfile_id(), contractAsManager);
        vm.stopPrank();

        vm.startPrank(facilitator().wearer);
        address payable shipAddress3 = gameManager().reviewRecipient(
            poolProfile_anchor(),
            GameManagerStrategy.ShipStatus.Accepted,
            ShipInitData(true, true, true, "Ship Name 3", Metadata(1, "Ship 3"), team(1).wearer, shipOperator(2).id)
        );
        vm.stopPrank();

        ship3 = GrantShipStrategy(shipAddress3);

        // Finally, we allocate

        address[] memory recipientAddresses = new address[](3);
        recipientAddresses[0] = recipientAddress;
        recipientAddresses[1] = recipientAddress2;
        recipientAddresses[2] = recipientAddress3;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 20_000e18;
        amounts[1] = 40_000e18;
        amounts[2] = 30_000e18;

        bytes memory data = abi.encode(recipientAddresses, amounts, _GAME_AMOUNT);

        vm.startPrank(facilitator().wearer);
        allo().allocate(gameManager().getPoolId(), data);
        vm.stopPrank();

        return recipientAddresses;
    }

    function _quick_fund_manager() internal {
        vm.startPrank(arbWhale);
        ARB().transfer(facilitator().wearer, _GAME_AMOUNT);
        vm.stopPrank();

        uint256 poolId = gameManager().getPoolId();

        vm.startPrank(facilitator().wearer);
        ARB().approve(address(allo()), _GAME_AMOUNT);

        allo().fundPool(poolId, _GAME_AMOUNT);

        vm.stopPrank();
    }

    function _register_create_reject() internal returns (address applicantId) {
        applicantId = _register_create_round();

        address[] memory contractAsManager = new address[](1);
        contractAsManager[0] = address(gameManager());
        bytes32 profileId = registry().getProfileByAnchor(profile1_anchor()).id;

        vm.startPrank(profile1_owner());
        registry().addMembers(profileId, contractAsManager);
        vm.stopPrank();

        vm.expectEmit(true, true, true, true);
        emit ApplicationRejected(applicantId);

        vm.startPrank(facilitator().wearer);
        gameManager().reviewRecipient(
            applicantId,
            GameManagerStrategy.ShipStatus.Rejected,
            ShipInitData(true, true, true, "Ship Name", Metadata(1, "Ship 1"), team(0).wearer, shipOperator(0).id)
        );
        vm.stopPrank();
    }

    function _register_create_approve() internal returns (address applicantId) {
        applicantId = _register_create_round();

        address[] memory contractAsManager = new address[](1);
        contractAsManager[0] = address(gameManager());
        bytes32 profileId = registry().getProfileByAnchor(profile1_anchor()).id;

        vm.startPrank(profile1_owner());
        registry().addMembers(profileId, contractAsManager);
        vm.stopPrank();

        vm.startPrank(facilitator().wearer);
        address payable shipAddress = gameManager().reviewRecipient(
            applicantId,
            GameManagerStrategy.ShipStatus.Accepted,
            ShipInitData(true, true, true, "Ship Name", Metadata(1, "Ship 1"), team(0).wearer, shipOperator(0).id)
        );
        vm.stopPrank();

        ship = GrantShipStrategy(shipAddress);
    }

    function _register_create_round() internal returns (address recipientId) {
        recipientId = _register_recipient();

        address arbAddress = address(ARB());

        vm.startPrank(facilitator().wearer);

        vm.expectEmit(true, true, true, true);
        emit RoundCreated(0, arbAddress, _GAME_AMOUNT);

        gameManager().createRound(_GAME_AMOUNT, arbAddress);
        vm.stopPrank();
    }

    function _register_recipient_return_data() internal returns (address recipientId, bytes memory data) {
        recipientId = profile1_anchor();

        Metadata memory metadata = Metadata(1, "Ship 1");

        data = abi.encode(recipientId, "Ship Name", metadata);

        vm.expectEmit(true, true, true, true);
        emit Registered(recipientId, data, profile1_member1());

        vm.startPrank(profile1_member1());
        allo().registerRecipient(gameManager().getPoolId(), data);
        vm.stopPrank();
    }

    function _register_recipient() internal returns (address recipientId) {
        (recipientId,) = _register_recipient_return_data();
    }
}
