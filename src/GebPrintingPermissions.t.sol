pragma solidity ^0.6.7;

import "ds-test/test.sol";
import "geb-protocol-token-authority/ProtocolTokenAuthority.sol";
import "./GebPrintingPermissions.sol";

contract GebPrintingPermissionsTest is DSTest {
    GebPrintingPermissions permissions;
    ProtocolTokenAuthority tokenAuthority;

    function setUp() public {
        tokenAuthority = new ProtocolTokenAuthority();
        permissions = new GebPrintingPermissions(address(tokenAuthority));
    }

    function testModifyParameters() public {

    }
    function testGiveUpAuthRoot() public {

    }
    function testFailGiveUpAuthRoot() public {

    }
    function testGiveUpAuthOwnership() public {

    }
    function testFailGiveUpAuthOwnership() public {

    }

    function testCover() public {

    }
    function testFailCoverAlreadyCovered() public {

    }
    function testFailCoverNonDebtAuctionHouse() public {

    }
    function testFailCoverWithoutAuthorityPermission() public {

    }

    function testCoverUncoverImmediately() public {

    }
    function testFailUncoverUncovered() public {

    }
    function testFailStartUncoverWhileCurrentHouseHasOutstandingAuctions() public {

    }
    function testFailStartUncoverWhilePreviousHouseHasOutstandingAuctions() public {

    }
    function testFailStartUncoverWhenNotEnoughSystemsCovered() public {

    }

    function testAbandonUncover() public {

    }
    function testFailAbandonUncovered() public {

    }
    function testFailAbandonWithoutStarting() public {

    }

    function testEndUncover() public {

    }
    function testEndUncoverWhenDebtHousesUnauthed() public {

    }
    function testFailEndUncoverUncovered() public {

    }
    function testFailEndUncoverWithoutStarting() public {

    }
    function testFailEndUncoverBeforeCooldown() public {

    }
    function testFailEndUncoverWhileCurrentHouseHasOutstandingAuctions() public {

    }
    function testFailEndUncoverWhilePreviousHouseHasOutstandingAuctions() public {

    }
    function testFailEndUncoverWhenNotEnoughSystemsCovered() public {

    }

    function testUpdateCurrentAuctionHouse() public {

    }
    function testFailUpdateCurrentHouseWhenNotCovered() public {

    }
    function testFailUpdateCurrentHouseSameHouse() public {

    }
    function testFailUpdateCurrentHouseWhenPreviousNotNull() public {

    }
    function testFailUpdateCurrentHouseNewHouseNotDebtAuction() public {

    }

    function testRemovePreviousAuctionHouse() public {

    }
    function testFailRemovePreviousHouseWhenNull() public {

    }
    function testFailRemovePreviousHouseWhenOutstandingAuctions() public {

    }
    function testFailRemovePreviousHouseWhenNotAuthedInProtocolAuth() public {

    }

    function testProposeIndefinitePrintingPermissions() public {

    }
    function testFailProposeIndefiniteWhenNotCovered() public {

    }
    function testFailProposeIndefiniteWithFreezeLowerThanCooldown() public {

    }
    function testFailProposeIndefiniteWithZeroFreeze() public {
      
    }
}
