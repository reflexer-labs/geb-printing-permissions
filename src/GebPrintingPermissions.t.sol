pragma solidity ^0.6.7;

import "ds-test/test.sol";
import "geb-protocol-token-authority/ProtocolTokenAuthority.sol";
import "./GebPrintingPermissions.sol";

contract TestAccountingEngine {
    address public debtAuctionHouse;

    function modifyParameters(bytes32 parameter, address data) external {
        debtAuctionHouse = data;
    }
}
contract TestDebtAuctionHouse {
    bytes32 public AUCTION_HOUSE_TYPE;
    uint256 public activeDebtAuctions;

    function modifyParameters(bytes32 parameter, uint256 data) external {
        activeDebtAuctions = data;
    }
    function modifyParameters(bytes32 parameter, bytes32 data) external {
        AUCTION_HOUSE_TYPE = data;
    }
}

abstract contract Hevm {
    function warp(uint256) virtual public;
}

contract GebPrintingPermissionsTest is DSTest {
    Hevm hevm;

    GebPrintingPermissions permissions;
    ProtocolTokenAuthority tokenAuthority;

    TestAccountingEngine accountingEngine;
    TestDebtAuctionHouse debtAuctionHouse;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(604411200);

        tokenAuthority = new ProtocolTokenAuthority();
        permissions = new GebPrintingPermissions(address(tokenAuthority));

        debtAuctionHouse = new TestDebtAuctionHouse();
        accountingEngine = new TestAccountingEngine();

        accountingEngine.modifyParameters("debtAuctionHouse", address(debtAuctionHouse));
        debtAuctionHouse.modifyParameters("AUCTION_HOUSE_TYPE", bytes32("DEBT"));
    }

    function testModifyParameters() public {
        assertEq(permissions.unrevokableRightsCooldown(), 0);
        assertEq(permissions.denyRightsCooldown(), 0);
        assertEq(permissions.addRightsCooldown(), 0);

        permissions.modifyParameters("unrevokableRightsCooldown", 1);
        permissions.modifyParameters("denyRightsCooldown", 2);
        permissions.modifyParameters("addRightsCooldown", 3);

        assertEq(permissions.unrevokableRightsCooldown(), 1);
        assertEq(permissions.denyRightsCooldown(), 2);
        assertEq(permissions.addRightsCooldown(), 3);
    }

    function testGiveUpAuthRoot() public {
        tokenAuthority.setOwner(address(permissions));
        tokenAuthority.setRoot(address(permissions));

        assertEq(tokenAuthority.root(), address(permissions));
        assertEq(tokenAuthority.owner(), address(permissions));

        permissions.giveUpAuthorityRoot();

        assertEq(tokenAuthority.root(), address(0));
        assertEq(tokenAuthority.owner(), address(permissions));
    }
    function testFailGiveUpAuthRoot() public {
        tokenAuthority.setOwner(address(permissions));

        assertEq(tokenAuthority.root(), address(this));
        assertEq(tokenAuthority.owner(), address(permissions));

        permissions.giveUpAuthorityRoot();
    }
    function testGiveUpAuthOwnership() public {
        tokenAuthority.setOwner(address(permissions));
        tokenAuthority.setRoot(address(permissions));

        assertEq(tokenAuthority.root(), address(permissions));
        assertEq(tokenAuthority.owner(), address(permissions));

        permissions.giveUpAuthorityOwnership();

        assertEq(tokenAuthority.root(), address(permissions));
        assertEq(tokenAuthority.owner(), address(0));
    }
    function testFailGiveUpAuthOwnership() public {
        assertEq(tokenAuthority.root(), address(this));
        assertEq(tokenAuthority.owner(), address(0));

        permissions.giveUpAuthorityOwnership();
    }

    function testCover() public {
        tokenAuthority.setOwner(address(permissions));
        permissions.coverSystem(address(accountingEngine));

        (
          bool covered,
          uint256 revokeRightsDeadline,
          uint256 uncoverCooldownEnd,
          uint256 withdrawAddedRightsDeadline,
          address previousDebtAuctionHouse,
          address currentDebtAuctionHouse
        ) = permissions.allowedSystems(address(accountingEngine));

        assertTrue(covered);
        assertEq(revokeRightsDeadline, uint(-1));
        assertEq(uncoverCooldownEnd, 0);
        assertEq(withdrawAddedRightsDeadline, now);
        assertTrue(previousDebtAuctionHouse == address(0));
        assertTrue(currentDebtAuctionHouse == address(debtAuctionHouse));

        assertEq(permissions.coveredSystems(), 1);
        assertEq(permissions.usedAuctionHouses(address(debtAuctionHouse)), 1);
        assertEq(tokenAuthority.authorizedAccounts(address(debtAuctionHouse)), 1);
    }
    function testFailCoverAlreadyCovered() public {
        tokenAuthority.setOwner(address(permissions));
        permissions.coverSystem(address(accountingEngine));
        permissions.coverSystem(address(accountingEngine));
    }
    function testFailCoverSameAuctionHouseTwice() public {
        tokenAuthority.setOwner(address(permissions));
        permissions.coverSystem(address(accountingEngine));

        hevm.warp(now + 1);

        TestAccountingEngine newAccountingEngine = new TestAccountingEngine();
        newAccountingEngine.modifyParameters("debtAuctionHouse", address(debtAuctionHouse));
        permissions.coverSystem(address(newAccountingEngine));
    }
    function testFailCoverNonDebtAuctionHouse() public {
        accountingEngine = new TestAccountingEngine();
        accountingEngine.modifyParameters("debtAuctionHouse", address(0));
        permissions.coverSystem(address(accountingEngine));
    }
    function testFailCoverWithoutAuthorityPermission() public {
        permissions.coverSystem(address(accountingEngine));
    }

    function testCoverUncoverImmediately() public {
        tokenAuthority.setOwner(address(permissions));

        permissions.modifyParameters("addRightsCooldown", 1);
        permissions.coverSystem(address(accountingEngine));

        permissions.startUncoverSystem(address(accountingEngine));
        assertEq(tokenAuthority.authorizedAccounts(address(debtAuctionHouse)), 0);
        assertEq(permissions.usedAuctionHouses(address(debtAuctionHouse)), 0);
    }
    function testFailUncoverUncovered() public {
        tokenAuthority.setOwner(address(permissions));

        permissions.modifyParameters("addRightsCooldown", 1);
        permissions.coverSystem(address(accountingEngine));

        permissions.startUncoverSystem(address(accountingEngine));
        permissions.startUncoverSystem(address(accountingEngine));
    }
    function testFailStartUncoverWhileCurrentHouseHasOutstandingAuctions() public {
        tokenAuthority.setOwner(address(permissions));

        permissions.modifyParameters("addRightsCooldown", 1);
        permissions.coverSystem(address(accountingEngine));

        debtAuctionHouse.modifyParameters("activeDebtAuctions", 1);

        permissions.startUncoverSystem(address(accountingEngine));
    }
    function testFailStartUncoverWhilePreviousHouseHasOutstandingAuctions() public {
        tokenAuthority.setOwner(address(permissions));

        permissions.modifyParameters("addRightsCooldown", 1);
        permissions.coverSystem(address(accountingEngine));

        TestDebtAuctionHouse newDebtAuctionHouse = new TestDebtAuctionHouse();
        newDebtAuctionHouse.modifyParameters("AUCTION_HOUSE_TYPE", bytes32("DEBT"));
        newDebtAuctionHouse.modifyParameters("activeDebtAuctions", 1);

        accountingEngine.modifyParameters("debtAuctionHouse", address(newDebtAuctionHouse));

        permissions.updateCurrentDebtAuctionHouse(address(accountingEngine));
        permissions.startUncoverSystem(address(accountingEngine));
    }
    function testFailStartUncoverWhenNotEnoughSystemsCovered() public {
        tokenAuthority.setOwner(address(permissions));

        permissions.coverSystem(address(accountingEngine));
        hevm.warp(now + 1);

        permissions.startUncoverSystem(address(accountingEngine));
    }

    function testAbandonUncover() public {
        tokenAuthority.setOwner(address(permissions));
        permissions.coverSystem(address(accountingEngine));

        hevm.warp(now + 1);

        TestDebtAuctionHouse newDebtAuctionHouse = new TestDebtAuctionHouse();
        TestAccountingEngine newAccountingEngine = new TestAccountingEngine();

        newAccountingEngine.modifyParameters("debtAuctionHouse", address(newDebtAuctionHouse));
        newDebtAuctionHouse.modifyParameters("AUCTION_HOUSE_TYPE", bytes32("DEBT"));

        permissions.coverSystem(address(newAccountingEngine));
        permissions.startUncoverSystem(address(accountingEngine));

        (
          bool covered,
          ,
          uint256 uncoverCooldownEnd,
          ,
          ,
        ) = permissions.allowedSystems(address(accountingEngine));

        assertTrue(covered);
        assertTrue(uncoverCooldownEnd > 0);

        permissions.abandonUncoverSystem(address(accountingEngine));

        (
          covered,
          ,
          uncoverCooldownEnd,
          ,
          ,
        ) = permissions.allowedSystems(address(accountingEngine));

        assertTrue(covered);
        assertTrue(uncoverCooldownEnd == 0);

        assertEq(tokenAuthority.authorizedAccounts(address(debtAuctionHouse)), 1);
        assertEq(permissions.usedAuctionHouses(address(debtAuctionHouse)), 1);
    }
    function testFailAbandonWithoutStarting() public {
        tokenAuthority.setOwner(address(permissions));

        permissions.modifyParameters("addRightsCooldown", 1);
        permissions.coverSystem(address(accountingEngine));
        permissions.endUncoverSystem(address(accountingEngine));
    }

    function testEndUncover() public {
        tokenAuthority.setOwner(address(permissions));
        permissions.coverSystem(address(accountingEngine));

        hevm.warp(now + 1);

        TestDebtAuctionHouse newDebtAuctionHouse = new TestDebtAuctionHouse();
        TestAccountingEngine newAccountingEngine = new TestAccountingEngine();

        newAccountingEngine.modifyParameters("debtAuctionHouse", address(newDebtAuctionHouse));
        newDebtAuctionHouse.modifyParameters("AUCTION_HOUSE_TYPE", bytes32("DEBT"));

        permissions.coverSystem(address(newAccountingEngine));

        permissions.startUncoverSystem(address(accountingEngine));
        hevm.warp(now + 1);
        permissions.endUncoverSystem(address(accountingEngine));

        assertEq(tokenAuthority.authorizedAccounts(address(debtAuctionHouse)), 0);

        (
          bool covered,
          uint256 revokeRightsDeadline,
          uint256 uncoverCooldownEnd,
          uint256 withdrawAddedRightsDeadline,
          address previousDebtAuctionHouse,
          address currentDebtAuctionHouse
        ) = permissions.allowedSystems(address(accountingEngine));

        assertTrue(!covered);
        assertEq(revokeRightsDeadline, 0);
        assertEq(uncoverCooldownEnd, 0);
        assertEq(withdrawAddedRightsDeadline, 0);
        assertTrue(previousDebtAuctionHouse == address(0));
        assertTrue(currentDebtAuctionHouse == address(0));

        assertEq(permissions.usedAuctionHouses(address(debtAuctionHouse)), 0);
        assertEq(permissions.usedAuctionHouses(address(newDebtAuctionHouse)), 1);
    }
    function testEndUncoverWhenDebtHousesUnauthed() public {
        tokenAuthority.setOwner(address(permissions));
        permissions.coverSystem(address(accountingEngine));

        hevm.warp(now + 1);

        tokenAuthority.removeAuthorization(address(debtAuctionHouse));

        TestDebtAuctionHouse newDebtAuctionHouse = new TestDebtAuctionHouse();
        TestAccountingEngine newAccountingEngine = new TestAccountingEngine();

        newAccountingEngine.modifyParameters("debtAuctionHouse", address(newDebtAuctionHouse));
        newDebtAuctionHouse.modifyParameters("AUCTION_HOUSE_TYPE", bytes32("DEBT"));

        permissions.coverSystem(address(newAccountingEngine));

        permissions.startUncoverSystem(address(accountingEngine));
        hevm.warp(now + 1);
        permissions.endUncoverSystem(address(accountingEngine));

        (
          bool covered,
          uint256 revokeRightsDeadline,
          uint256 uncoverCooldownEnd,
          uint256 withdrawAddedRightsDeadline,
          address previousDebtAuctionHouse,
          address currentDebtAuctionHouse
        ) = permissions.allowedSystems(address(accountingEngine));

        assertTrue(!covered);
        assertEq(revokeRightsDeadline, 0);
        assertEq(uncoverCooldownEnd, 0);
        assertEq(withdrawAddedRightsDeadline, 0);
        assertTrue(previousDebtAuctionHouse == address(0));
        assertTrue(currentDebtAuctionHouse == address(0));

        assertEq(permissions.usedAuctionHouses(address(debtAuctionHouse)), 0);
        assertEq(permissions.usedAuctionHouses(address(newDebtAuctionHouse)), 1);
    }
    function testFailEndUncoverWithoutStarting() public {
        tokenAuthority.setOwner(address(permissions));
        permissions.coverSystem(address(accountingEngine));

        hevm.warp(now + 1);

        TestDebtAuctionHouse newDebtAuctionHouse = new TestDebtAuctionHouse();
        TestAccountingEngine newAccountingEngine = new TestAccountingEngine();

        newAccountingEngine.modifyParameters("debtAuctionHouse", address(debtAuctionHouse));
        debtAuctionHouse.modifyParameters("AUCTION_HOUSE_TYPE", bytes32("DEBT"));

        permissions.coverSystem(address(newAccountingEngine));

        hevm.warp(now + 1);
        permissions.endUncoverSystem(address(accountingEngine));
    }
    function testFailEndUncoverBeforeCooldown() public {
        tokenAuthority.setOwner(address(permissions));
        permissions.modifyParameters("denyRightsCooldown", 10);
        permissions.coverSystem(address(accountingEngine));

        hevm.warp(now + 1);

        TestDebtAuctionHouse newDebtAuctionHouse = new TestDebtAuctionHouse();
        TestAccountingEngine newAccountingEngine = new TestAccountingEngine();

        newAccountingEngine.modifyParameters("debtAuctionHouse", address(debtAuctionHouse));
        debtAuctionHouse.modifyParameters("AUCTION_HOUSE_TYPE", bytes32("DEBT"));

        permissions.coverSystem(address(newAccountingEngine));

        permissions.startUncoverSystem(address(accountingEngine));
        hevm.warp(now + 1);
        permissions.endUncoverSystem(address(accountingEngine));
    }
    function testFailEndUncoverWhileCurrentHouseHasOutstandingAuctions() public {
        tokenAuthority.setOwner(address(permissions));
        permissions.coverSystem(address(accountingEngine));

        hevm.warp(now + 1);

        TestDebtAuctionHouse newDebtAuctionHouse = new TestDebtAuctionHouse();
        TestAccountingEngine newAccountingEngine = new TestAccountingEngine();

        newAccountingEngine.modifyParameters("debtAuctionHouse", address(debtAuctionHouse));
        debtAuctionHouse.modifyParameters("AUCTION_HOUSE_TYPE", bytes32("DEBT"));

        permissions.coverSystem(address(newAccountingEngine));

        permissions.startUncoverSystem(address(accountingEngine));
        hevm.warp(now + 1);

        debtAuctionHouse.modifyParameters("activeDebtAuctions", 1);
        permissions.endUncoverSystem(address(accountingEngine));
    }
    function testFailEndUncoverWhilePreviousHouseHasOutstandingAuctions() public {
        tokenAuthority.setOwner(address(permissions));
        permissions.modifyParameters("addRightsCooldown", 1);
        permissions.coverSystem(address(accountingEngine));

        permissions.startUncoverSystem(address(accountingEngine));
        hevm.warp(now + 1);

        TestDebtAuctionHouse newDebtAuctionHouse = new TestDebtAuctionHouse();
        newDebtAuctionHouse.modifyParameters("AUCTION_HOUSE_TYPE", bytes32("DEBT"));
        newDebtAuctionHouse.modifyParameters("activeDebtAuctions", 1);

        accountingEngine.modifyParameters("debtAuctionHouse", address(newDebtAuctionHouse));
        permissions.updateCurrentDebtAuctionHouse(address(accountingEngine));

        permissions.endUncoverSystem(address(accountingEngine));
    }
    function testFailEndUncoverWhenNotEnoughSystemsCovered() public {
        tokenAuthority.setOwner(address(permissions));
        permissions.coverSystem(address(accountingEngine));

        hevm.warp(now + 1);

        TestDebtAuctionHouse newDebtAuctionHouse = new TestDebtAuctionHouse();
        TestAccountingEngine newAccountingEngine = new TestAccountingEngine();

        newAccountingEngine.modifyParameters("debtAuctionHouse", address(debtAuctionHouse));
        debtAuctionHouse.modifyParameters("AUCTION_HOUSE_TYPE", bytes32("DEBT"));

        permissions.coverSystem(address(newAccountingEngine));

        permissions.startUncoverSystem(address(accountingEngine));
        permissions.startUncoverSystem(address(newAccountingEngine));

        permissions.endUncoverSystem(address(newAccountingEngine));
        permissions.endUncoverSystem(address(accountingEngine));
    }

    function testUpdateCurrentAuctionHouse() public {
        tokenAuthority.setOwner(address(permissions));
        permissions.coverSystem(address(accountingEngine));

        TestDebtAuctionHouse newDebtAuctionHouse = new TestDebtAuctionHouse();
        newDebtAuctionHouse.modifyParameters("AUCTION_HOUSE_TYPE", bytes32("DEBT"));
        newDebtAuctionHouse.modifyParameters("activeDebtAuctions", 1);

        accountingEngine.modifyParameters("debtAuctionHouse", address(newDebtAuctionHouse));

        assertEq(tokenAuthority.authorizedAccounts(address(newDebtAuctionHouse)), 0);
        permissions.updateCurrentDebtAuctionHouse(address(accountingEngine));

        (
          ,
          ,
          ,
          ,
          address previousDebtAuctionHouse,
          address currentDebtAuctionHouse
        ) = permissions.allowedSystems(address(accountingEngine));

        assertTrue(previousDebtAuctionHouse == address(debtAuctionHouse));
        assertTrue(currentDebtAuctionHouse == address(newDebtAuctionHouse));

        assertEq(tokenAuthority.authorizedAccounts(address(newDebtAuctionHouse)), 1);
    }
    function testFailUpdateCurrentHouseWhenNotCovered() public {
        tokenAuthority.setOwner(address(permissions));
        permissions.modifyParameters("addRightsCooldown", 1);
        permissions.coverSystem(address(accountingEngine));

        TestDebtAuctionHouse newDebtAuctionHouse = new TestDebtAuctionHouse();
        newDebtAuctionHouse.modifyParameters("AUCTION_HOUSE_TYPE", bytes32("DEBT"));
        newDebtAuctionHouse.modifyParameters("activeDebtAuctions", 1);

        accountingEngine.modifyParameters("debtAuctionHouse", address(newDebtAuctionHouse));

        permissions.startUncoverSystem(address(accountingEngine));
        permissions.updateCurrentDebtAuctionHouse(address(accountingEngine));
    }
    function testFailUpdateCurrentHouseSameHouse() public {
        tokenAuthority.setOwner(address(permissions));
        permissions.coverSystem(address(accountingEngine));
        permissions.updateCurrentDebtAuctionHouse(address(accountingEngine));
    }
    function testFailUpdateCurrentHouseNewHouseAlreadyUsed() public {
        tokenAuthority.setOwner(address(permissions));
        permissions.coverSystem(address(accountingEngine));

        hevm.warp(now + 1);

        tokenAuthority.removeAuthorization(address(debtAuctionHouse));

        TestDebtAuctionHouse newDebtAuctionHouse = new TestDebtAuctionHouse();
        TestAccountingEngine newAccountingEngine = new TestAccountingEngine();

        newAccountingEngine.modifyParameters("debtAuctionHouse", address(newDebtAuctionHouse));
        newDebtAuctionHouse.modifyParameters("AUCTION_HOUSE_TYPE", bytes32("DEBT"));

        permissions.coverSystem(address(newAccountingEngine));

        accountingEngine.modifyParameters("debtAuctionHouse", address(newDebtAuctionHouse));
        permissions.updateCurrentDebtAuctionHouse(address(accountingEngine));
    }
    function testFailUpdateCurrentHouseWhenPreviousNotNull() public {
        tokenAuthority.setOwner(address(permissions));
        permissions.coverSystem(address(accountingEngine));

        TestDebtAuctionHouse newDebtAuctionHouse = new TestDebtAuctionHouse();
        newDebtAuctionHouse.modifyParameters("AUCTION_HOUSE_TYPE", bytes32("DEBT"));
        newDebtAuctionHouse.modifyParameters("activeDebtAuctions", 1);

        accountingEngine.modifyParameters("debtAuctionHouse", address(newDebtAuctionHouse));
        permissions.updateCurrentDebtAuctionHouse(address(accountingEngine));

        newDebtAuctionHouse = new TestDebtAuctionHouse();
        newDebtAuctionHouse.modifyParameters("AUCTION_HOUSE_TYPE", bytes32("DEBT"));
        newDebtAuctionHouse.modifyParameters("activeDebtAuctions", 1);

        accountingEngine.modifyParameters("debtAuctionHouse", address(newDebtAuctionHouse));
        permissions.updateCurrentDebtAuctionHouse(address(accountingEngine));
    }
    function testFailUpdateCurrentHouseNewHouseNotDebtAuction() public {
        tokenAuthority.setOwner(address(permissions));
        permissions.coverSystem(address(accountingEngine));

        TestDebtAuctionHouse newDebtAuctionHouse = new TestDebtAuctionHouse();
        newDebtAuctionHouse.modifyParameters("activeDebtAuctions", 1);

        accountingEngine.modifyParameters("debtAuctionHouse", address(newDebtAuctionHouse));
        permissions.updateCurrentDebtAuctionHouse(address(accountingEngine));
    }

    function testRemovePreviousAuctionHouse() public {
        tokenAuthority.setOwner(address(permissions));
        permissions.coverSystem(address(accountingEngine));

        TestDebtAuctionHouse newDebtAuctionHouse = new TestDebtAuctionHouse();
        newDebtAuctionHouse.modifyParameters("AUCTION_HOUSE_TYPE", bytes32("DEBT"));
        newDebtAuctionHouse.modifyParameters("activeDebtAuctions", 1);

        accountingEngine.modifyParameters("debtAuctionHouse", address(newDebtAuctionHouse));
        permissions.updateCurrentDebtAuctionHouse(address(accountingEngine));

        assertEq(tokenAuthority.authorizedAccounts(address(debtAuctionHouse)), 1);

        permissions.removePreviousDebtAuctionHouse(address(accountingEngine));

        (
          ,
          ,
          ,
          ,
          address previousDebtAuctionHouse,
          address currentDebtAuctionHouse
        ) = permissions.allowedSystems(address(accountingEngine));

        assertTrue(previousDebtAuctionHouse == address(0));
        assertTrue(currentDebtAuctionHouse == address(newDebtAuctionHouse));

        assertEq(tokenAuthority.authorizedAccounts(address(debtAuctionHouse)), 0);
        assertEq(tokenAuthority.authorizedAccounts(address(newDebtAuctionHouse)), 1);
    }
    function testFailRemovePreviousHouseWhenNull() public {
        tokenAuthority.setOwner(address(permissions));
        permissions.coverSystem(address(accountingEngine));
        permissions.removePreviousDebtAuctionHouse(address(accountingEngine));
    }
    function testFailRemovePreviousHouseWhenOutstandingAuctions() public {
        tokenAuthority.setOwner(address(permissions));
        permissions.coverSystem(address(accountingEngine));

        TestDebtAuctionHouse newDebtAuctionHouse = new TestDebtAuctionHouse();
        newDebtAuctionHouse.modifyParameters("AUCTION_HOUSE_TYPE", bytes32("DEBT"));

        accountingEngine.modifyParameters("debtAuctionHouse", address(newDebtAuctionHouse));
        permissions.updateCurrentDebtAuctionHouse(address(accountingEngine));

        debtAuctionHouse.modifyParameters("activeDebtAuctions", 1);

        permissions.removePreviousDebtAuctionHouse(address(accountingEngine));
    }
    function testFailRemovePreviousHouseWhenNotAuthedInProtocolAuth() public {
        tokenAuthority.setOwner(address(permissions));
        permissions.coverSystem(address(accountingEngine));

        TestDebtAuctionHouse newDebtAuctionHouse = new TestDebtAuctionHouse();
        newDebtAuctionHouse.modifyParameters("AUCTION_HOUSE_TYPE", bytes32("DEBT"));
        newDebtAuctionHouse.modifyParameters("activeDebtAuctions", 1);

        accountingEngine.modifyParameters("debtAuctionHouse", address(newDebtAuctionHouse));
        permissions.updateCurrentDebtAuctionHouse(address(accountingEngine));

        tokenAuthority.setOwner(address(0));

        permissions.removePreviousDebtAuctionHouse(address(accountingEngine));
    }

    function testProposeIndefinitePrintingPermissions() public {
        tokenAuthority.setOwner(address(permissions));
        permissions.coverSystem(address(accountingEngine));

        (
          ,
          uint256 revokeRightsDeadline,
          ,
          ,
          ,

        ) = permissions.allowedSystems(address(accountingEngine));
        assertEq(revokeRightsDeadline, uint(-1));

        permissions.proposeIndefinitePrintingPermissions(address(accountingEngine), 3600);

        (
          ,
          revokeRightsDeadline,
          ,
          ,
          ,

        ) = permissions.allowedSystems(address(accountingEngine));
        assertEq(revokeRightsDeadline, now + 3600);

        assertEq(tokenAuthority.authorizedAccounts(address(debtAuctionHouse)), 1);
    }
    function testFailProposeIndefiniteWhenNotCovered() public {
        tokenAuthority.setOwner(address(permissions));
        permissions.proposeIndefinitePrintingPermissions(address(accountingEngine), 3600);
    }
    function testFailProposeIndefiniteWithFreezeLowerThanCooldown() public {
        permissions.modifyParameters("unrevokableRightsCooldown", 3600);
        tokenAuthority.setOwner(address(permissions));
        permissions.coverSystem(address(accountingEngine));

        (
          ,
          uint256 revokeRightsDeadline,
          ,
          ,
          ,

        ) = permissions.allowedSystems(address(accountingEngine));
        assertEq(revokeRightsDeadline, uint(-1));

        permissions.proposeIndefinitePrintingPermissions(address(accountingEngine), 1);
    }
    function testFailProposeIndefiniteWithZeroFreeze() public {
        tokenAuthority.setOwner(address(permissions));
        permissions.coverSystem(address(accountingEngine));

        (
          ,
          uint256 revokeRightsDeadline,
          ,
          ,
          ,

        ) = permissions.allowedSystems(address(accountingEngine));
        assertEq(revokeRightsDeadline, uint(-1));

        permissions.proposeIndefinitePrintingPermissions(address(accountingEngine), 0);
    }
}
