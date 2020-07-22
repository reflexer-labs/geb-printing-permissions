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
    uint256 public activeDebtAuctionsAccumulator;

    function modifyParameters(bytes32 parameter, uint256 data) external {
        activeDebtAuctionsAccumulator = data;
    }
    function modifyParameters(bytes32 parameter, bytes32 data) external {
        AUCTION_HOUSE_TYPE = data;
    }
}

contract GebPrintingPermissionsTest is DSTest {
    GebPrintingPermissions permissions;
    ProtocolTokenAuthority tokenAuthority;

    TestAccountingEngine accountingEngine;
    TestDebtAuctionHouse debtAuctionHouse;

    function setUp() public {
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
    }
    // function testFailCoverAlreadyCovered() public {
    //
    // }
    // function testFailCoverNonDebtAuctionHouse() public {
    //
    // }
    // function testFailCoverWithoutAuthorityPermission() public {
    //
    // }

    // function testCoverUncoverImmediately() public {
    //
    // }
    // function testFailUncoverUncovered() public {
    //
    // }
    // function testFailStartUncoverWhileCurrentHouseHasOutstandingAuctions() public {
    //
    // }
    // function testFailStartUncoverWhilePreviousHouseHasOutstandingAuctions() public {
    //
    // }
    // function testFailStartUncoverWhenNotEnoughSystemsCovered() public {
    //
    // }
    //
    // function testAbandonUncover() public {
    //
    // }
    // function testFailAbandonUncovered() public {
    //
    // }
    // function testFailAbandonWithoutStarting() public {
    //
    // }
    //
    // function testEndUncover() public {
    //
    // }
    // function testEndUncoverWhenDebtHousesUnauthed() public {
    //
    // }
    // function testFailEndUncoverUncovered() public {
    //
    // }
    // function testFailEndUncoverWithoutStarting() public {
    //
    // }
    // function testFailEndUncoverBeforeCooldown() public {
    //
    // }
    // function testFailEndUncoverWhileCurrentHouseHasOutstandingAuctions() public {
    //
    // }
    // function testFailEndUncoverWhilePreviousHouseHasOutstandingAuctions() public {
    //
    // }
    // function testFailEndUncoverWhenNotEnoughSystemsCovered() public {
    //
    // }
    //
    // function testUpdateCurrentAuctionHouse() public {
    //
    // }
    // function testFailUpdateCurrentHouseWhenNotCovered() public {
    //
    // }
    // function testFailUpdateCurrentHouseSameHouse() public {
    //
    // }
    // function testFailUpdateCurrentHouseWhenPreviousNotNull() public {
    //
    // }
    // function testFailUpdateCurrentHouseNewHouseNotDebtAuction() public {
    //
    // }
    //
    // function testRemovePreviousAuctionHouse() public {
    //
    // }
    // function testFailRemovePreviousHouseWhenNull() public {
    //
    // }
    // function testFailRemovePreviousHouseWhenOutstandingAuctions() public {
    //
    // }
    // function testFailRemovePreviousHouseWhenNotAuthedInProtocolAuth() public {
    //
    // }
    //
    // function testProposeIndefinitePrintingPermissions() public {
    //
    // }
    // function testFailProposeIndefiniteWhenNotCovered() public {
    //
    // }
    // function testFailProposeIndefiniteWithFreezeLowerThanCooldown() public {
    //
    // }
    // function testFailProposeIndefiniteWithZeroFreeze() public {
    //
    // }
}
