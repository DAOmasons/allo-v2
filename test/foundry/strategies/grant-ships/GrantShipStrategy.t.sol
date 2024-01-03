// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

// External Libraries

import {IHats} from "hats-protocol/Interfaces/IHats.sol";

// Interfaces
import {IStrategy} from "../../../../contracts/core/interfaces/IStrategy.sol";

// Strategy contracts
import {GrantShipStrategy} from "../../../../contracts/strategies/_poc/grant-ships/GrantShipStrategy.sol";

// Internal libraries
import {Errors} from "../../../../contracts/core/libraries/Errors.sol";
import {Metadata} from "../../../../contracts/core/libraries/Metadata.sol";
import {Native} from "../../../../contracts/core/libraries/Native.sol";

// Test libraries
import {AlloSetup} from "../../shared/AlloSetup.sol";
import {RegistrySetupFullLive} from "../../shared/RegistrySetup.sol";
import {EventSetup} from "../../shared/EventSetup.sol";

contract GrantShiptStrategyTest is Test, RegistrySetupFullLive, AlloSetup, Native, EventSetup, Errors {
    Metadata public shipMetadata;

    GrantShipStrategy public strategyImplementation;
    GrantShipStrategy public strategy;

    uint256 poolId;
    address token = NATIVE;

    address[] poolAdminAsManager = new address[](1);

    IHats public hats;

    function setUp() public {
        vm.createSelectFork({blockNumber: 18_562_300, urlOrAlias: "opgoerli"});
        __RegistrySetupFullLive();
        __AlloSetupLive();

        strategyImplementation = __setup_and_create_strategy();

        address payable strategyAddress;
        (poolId, strategyAddress) = _createPool(
            true, // registryGating
            true, // metadataRequired
            true // grantAmountRequired
        );

        strategy = GrantShipStrategy(strategyAddress);
    }

    // ================= Helpers ===================

    function __setup_strategy() internal returns (GrantShipStrategy) {
        return new GrantShipStrategy(address(allo()), "GrantShipStrategy");
    }

    function __setup_and_create_strategy() internal returns (GrantShipStrategy) {
        strategyImplementation = __setup_strategy();
        return strategyImplementation;
    }

    function _createPool(bool _registryGating, bool _metadataRequired, bool _grantAmountRequired)
        internal
        returns (uint256 newPoolId, address payable strategyClone)
    {
        vm.deal(pool_admin(), 30e18);
        poolAdminAsManager[0] = pool_admin();

        vm.startPrank(pool_admin());

        newPoolId = allo().createPoolWithCustomStrategy{value: 30e18}(
            poolProfile_id(),
            address(strategyImplementation),
            abi.encode(_registryGating, _metadataRequired, _grantAmountRequired),
            token,
            30e18,
            Metadata(1, "grant-ship-data"),
            // pool manager/game facilitator role will be mediated through Hats Protocol
            // pool_admin address will be the game_facilitator multisig
            // using pool_admin as a single address for both roles
            poolAdminAsManager
        );

        vm.stopPrank();

        strategyClone = payable(address(allo().getPool(newPoolId).strategy));
    }

    // function __createPool(address strategy) internal returns (uint256 _poolId) {
    //     vm.prank(pool_admin());
    //     _poolId = allo().createPool(
    //         poolProfile_id(),
    //         strategy,
    //         __enocdeInitializeParams(),
    //         address(superFakeDai),
    //         0,
    //         Metadata(1, "test"),
    //         pool_managers()
    //     );
    // }

    function _createHatsTree() internal {
        // hats = new IHats(makeAddr("hats"));

        // vm.startPrank(pool_admin());

        // uint256 _topHatId = hats.mintTopHat(pool_admin(), "testTopHat", "https://wwww/tophat.com/");

        // console.log("topHatId: %s", _topHatId);

        // vm.prank(_topHatWearer);

        // _facilitatorHatId = hats.createHat(_topHatId, "Facilitator Hat", 2, _eligibility, _toggle, true, "");

        // vm.prank(_topHatWearer);
        // hats.mintHat(_facilitatorHatId, _gameFacilitator);

        // for (uint32 i = 0; i < 3;) {
        //     vm.prank(_topHatWearer);
        //     _shipHatIds[i] = hats.createHat(
        //         _topHatId, string.concat("Ship Hat ", vm.toString(i + 1)), 1, _eligibility, _toggle, true, ""
        //     );

        //     _shipAddresses[i] = address(uint160(50 + i));

        //     vm.prank(_topHatWearer);
        //     hats.mintHat(_shipHatIds[i], _shipAddresses[i]);

        //     vm.prank(_shipAddresses[i]);
        //     _operatorHatIds[i] = hats.createHat(
        //         _shipHatIds[i],
        //         string.concat("Ship Operator Hat ", vm.toString(i + 1)),
        //         3,
        //         address(555),
        //         address(333),
        //         true,
        //         ""
        //     );

        //     _shipOperators[i] = address(uint160(10 + i));

        //     vm.prank(_topHatWearer);
        //     hats.mintHat(_operatorHatIds[i], _shipOperators[i]);

        //     unchecked {
        //         ++i;
        //     }
        // }
    }

    function testtest() public {
        console.log("poolId: %s", poolId);
    }
}
