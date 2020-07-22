pragma solidity ^0.6.7;

import "ds-test/test.sol";

import "./GebPrintingPermissions.sol";

contract GebPrintingPermissionsTest is DSTest {
    GebPrintingPermissions permissions;

    function setUp() public {
        // permissions = new GebPrintingPermissions();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
