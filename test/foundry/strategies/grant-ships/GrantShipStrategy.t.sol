// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

// External Libraries
import "forge-std/Test.sol";

// Interfaces
import {IStrategy} from "../../../../contracts/core/interfaces/IStrategy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Strategy contracts
import {GrantShipStrategy} from "../../../../contracts/strategies/_poc/grant-ships/GrantShipStrategy.sol";
import {GameManagerStrategy} from "../../../../contracts/strategies/_poc/grant-ships/GameManagerStrategy.sol";

// Internal libraries
import {Errors} from "../../../../contracts/core/libraries/Errors.sol";
import {Metadata} from "../../../../contracts/core/libraries/Metadata.sol";
import {Native} from "../../../../contracts/core/libraries/Native.sol";
import {ShipInitData} from "../../../../contracts/strategies/_poc/grant-ships/libraries/GrantShipShared.sol";
// Test libraries
import {AlloSetup} from "../../shared/AlloSetup.sol";

import {GameManagerSetup} from "./GameManagerSetup.t.sol";
import {HatsSetupLive} from "./HatsSetup.sol";
import {EventSetup} from "../../shared/EventSetup.sol";

//Todo Test if each contract inherits a different version of the same contract
// Is this contract getting the same address that others recieve.
contract GrantShiptStrategyTest is Test, GameManagerSetup, EventSetup, Errors {
    // Events
    event RecipientStatusChanged(address recipientId, GrantShipStrategy.Status status);
    event MilestoneSubmitted(address recipientId, uint256 milestoneId, Metadata metadata);
    event MilestoneStatusChanged(address recipientId, uint256 milestoneId, IStrategy.Status status);
    event MilestonesSet(address recipientId, uint256 milestonesLength);
    event MilestonesReviewed(address recipientId, IStrategy.Status status);
    event PoolFunded(uint256 poolId, uint256 amountAfterFee, uint256 feeAmount);
    // ================= Setup =====================

    function setUp() public {
        vm.createSelectFork({blockNumber: 166_807_779, urlOrAlias: "arbitrumOne"});
        __RegistrySetupFullLive();
        __AlloSetupLive();
        __HatsSetupLive(pool_admin());
        __GameSetup();
    }

    // ================= Deployment & Init Tests =====================

    function test_deploy_manager() public {
        assertTrue(address(gameManager()) != address(0));
        assertTrue(address(gameManager().getAllo()) == address(allo()));
        assertTrue(gameManager().getStrategyId() == keccak256(abi.encode(gameManagerStrategyId)));
        assertTrue(address(hats()) == gameManager().getHatsAddress());
    }

    function test_init_manager() public {
        assertTrue(gameManager().currentRoundId() == 0);
        assertTrue(gameManager().currentRoundStartTime() == 0);
        assertTrue(gameManager().currentRoundEndTime() == 0);
        assertTrue(gameManager().currentRoundStatus() == IStrategy.Status.None);
        assertTrue(gameManager().token() == address(arbToken));
        assertTrue(gameManager().gameFacilitatorHatId() == facilitator().id);
    }

    function test_ships_created() public {
        for (uint256 i = 0; i < 3;) {
            _test_ship_created(i);
            unchecked {
                i++;
            }
        }
    }

    // ================= GrantShip Strategy =====================

    function test_isValidAllocator() public {
        assertTrue(ship(0).isValidAllocator(facilitator().wearer));
        assertTrue(ship(1).isValidAllocator(facilitator().wearer));
        assertTrue(ship(2).isValidAllocator(facilitator().wearer));

        assertFalse(ship(0).isValidAllocator(randomAddress()));
        assertFalse(ship(1).isValidAllocator(shipOperator(0).wearer));
        assertFalse(ship(2).isValidAllocator(team(0).wearer));
    }

    function test_registerRecipient() public {
        address recipientId = _register_recipient();

        GrantShipStrategy.Recipient memory recipient = ship(1).getRecipient(profile1_anchor());

        assertTrue(recipient.recipientAddress == recipient1());
        assertTrue(recipient.grantAmount == 1_000e18);
        assertTrue(keccak256(abi.encode(recipient.metadata.pointer)) == keccak256(abi.encode("team recipient 1")));
        assertTrue(recipient.metadata.protocol == 1);
        assertTrue(recipient.recipientStatus == IStrategy.Status.Pending);
        assertTrue(recipient.milestonesReviewStatus == IStrategy.Status.Pending);
        assertTrue(recipient.useRegistryAnchor);

        IStrategy.Status status = ship(1).getRecipientStatus(recipientId);
        assertTrue(uint8(status) == uint8(IStrategy.Status.Pending));
    }

    function testRevert_registerRecipient_UNAUTHORIZED() public {
        address recipientId = profile1_anchor();
        address recipientAddress = recipient1();
        address sender = profile2_member1(); // wrong sender
        uint256 grantAmount = 5e17; // 0.5 eth
        Metadata memory metadata = Metadata(1, "recipient-data");

        bytes memory data = abi.encode(recipientId, recipientAddress, grantAmount, metadata);
        vm.startPrank(address(allo()));

        vm.expectRevert(UNAUTHORIZED.selector);

        ship(1).registerRecipient(data, sender);
        vm.stopPrank();
    }

    function test_registerRecipient_allocate_accept() public {
        _register_recipient_allocate_accept();

        // _register_recipient_allocate_accept_set_milestones_by_ship_operator();
    }

    function test_register_recipient_allocate_reject() public {
        _register_recipient_allocate_reject();
    }

    function test_register_recipient_allocate_accept_set_milestones_by_pool_manager() public {
        _register_recipient_allocate_accept_set_milestones_by_ship_operator();
    }

    function test_register_recipient_allocate_accept_set_milestones_by_recipient() public {
        _register_recipient_allocate_accept_set_milestones_by_recipient();
    }

    // ================= Helpers =====================

    function _test_ship_created(uint256 _shipId) internal {
        // GrantShipStrategy shipStrategy = _getShipStrategy(_shipId);
        ShipInitData memory shipInitData = abi.decode(shipSetupData(_shipId), (ShipInitData));
        assertTrue(address(ship(_shipId).getAllo()) == address(allo()));
        assertTrue(ship(_shipId).getStrategyId() == keccak256(abi.encode(shipInitData.shipName)));
        assertTrue(ship(_shipId).registryGating());
        assertTrue(ship(_shipId).metadataRequired());
        assertTrue(ship(_shipId).grantAmountRequired());
        assertTrue(shipInitData.operatorHatId == ship(_shipId).operatorHatId());
        // Todo add tests for other params once they are added to Ship Strategy
    }

    function _getShipStrategy(uint256 _shipId) internal view returns (GrantShipStrategy) {
        address payable strategyAddress = gameManager().getShipAddress(_shipId);
        return GrantShipStrategy(strategyAddress);
    }

    function _register_recipient_return_data() internal returns (address recipientId, bytes memory data) {
        recipientId = profile1_anchor();
        address recipientAddress = recipient1();
        address sender = profile1_member1();
        uint256 grantAmount = 1_000e18; //
        Metadata memory metadata = Metadata(1, "team recipient 1");

        data = abi.encode(recipientId, recipientAddress, grantAmount, metadata);

        vm.startPrank(address(allo()));

        vm.expectEmit(false, false, false, true);
        emit Registered(recipientId, data, profile1_member1());

        ship(1).registerRecipient(data, sender);
        vm.stopPrank();
    }

    function _register_recipient() internal returns (address recipientId) {
        (recipientId,) = _register_recipient_return_data();
    }

    function _quick_fund_ship(uint256 _shipId) internal {
        vm.prank(arbWhale);
        ARB().transfer(facilitator().wearer, 30_000e18);

        uint256 poolId = ship(_shipId).getPoolId();

        vm.startPrank(facilitator().wearer);
        ARB().approve(address(allo()), 30_000e18);

        allo().fundPool(poolId, 30_000e18);

        vm.stopPrank();
    }

    function _register_recipient_allocate_accept() internal returns (address recipientId) {
        recipientId = _register_recipient();
        GrantShipStrategy.Status recipientStatus = IStrategy.Status.Accepted;
        uint256 grantAmount = 1_000e18;

        bytes memory data = abi.encode(recipientId, recipientStatus, grantAmount);
        _quick_fund_ship(1);

        vm.expectEmit(true, true, true, true);
        emit RecipientStatusChanged(recipientId, recipientStatus);
        emit Allocated(recipientId, grantAmount, address(ARB()), facilitator().wearer);

        vm.startPrank(address(allo()));
        ship(1).allocate(data, facilitator().wearer);
        vm.stopPrank();
    }

    function _register_recipient_allocate_reject() internal returns (address recipientId) {
        recipientId = _register_recipient();
        GrantShipStrategy.Status recipientStatus = IStrategy.Status.Rejected;
        uint256 grantAmount = 1_000e18;

        bytes memory data = abi.encode(recipientId, recipientStatus, grantAmount);
        _quick_fund_ship(1);

        console.log("----------IN TEST----------");
        console.log("recipientId: ", recipientId);
        console.log("recipientStatus: ", uint8(recipientStatus));
        vm.expectEmit(false, false, false, false);
        emit RecipientStatusChanged(recipientId, recipientStatus);

        vm.startPrank(address(allo()));
        ship(1).allocate(data, facilitator().wearer);
        vm.stopPrank();
    }

    function _register_recipient_allocate_accept_set_milestones_by_ship_operator()
        internal
        returns (address recipientId)
    {
        recipientId = _register_recipient_allocate_accept();

        GrantShipStrategy.Milestone[] memory milestones = new GrantShipStrategy.Milestone[](2);
        milestones[0] = GrantShipStrategy.Milestone({
            amountPercentage: 0.3e18,
            metadata: Metadata(1, "milestone-1"),
            milestoneStatus: IStrategy.Status.None
        });

        milestones[1] = GrantShipStrategy.Milestone({
            amountPercentage: 0.7e18,
            metadata: Metadata(1, "milestone-2"),
            milestoneStatus: IStrategy.Status.None
        });

        vm.expectEmit(true, true, true, true);

        emit MilestonesSet(recipientId, milestones.length);
        emit MilestonesReviewed(recipientId, IStrategy.Status.Accepted);

        vm.startPrank(shipOperator(1).wearer);
        ship(1).setMilestones(recipientId, milestones);
        vm.stopPrank();
    }

    function _register_recipient_allocate_accept_set_milestones_by_recipient() internal returns (address recipientId) {
        recipientId = _register_recipient_allocate_accept();

        GrantShipStrategy.Milestone[] memory milestones = new GrantShipStrategy.Milestone[](2);
        milestones[0] = GrantShipStrategy.Milestone({
            amountPercentage: 0.3e18,
            metadata: Metadata(1, "milestone-1"),
            milestoneStatus: IStrategy.Status.None
        });

        milestones[1] = GrantShipStrategy.Milestone({
            amountPercentage: 0.7e18,
            metadata: Metadata(1, "milestone-2"),
            milestoneStatus: IStrategy.Status.None
        });

        vm.expectEmit(true, true, true, true);

        emit MilestonesSet(recipientId, milestones.length);

        vm.startPrank(profile1_member1());
        ship(1).setMilestones(recipientId, milestones);
        vm.stopPrank();
    }
}
