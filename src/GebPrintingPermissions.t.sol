pragma solidity ^0.6.7;

import "ds-test/test.sol";
import "geb-protocol-token-authority/ProtocolTokenAuthority.sol";
import "./GebPrintingPermissions.sol";

contract GebPrintingPermissionsTest is DSTest {
    GebPrintingPermissions permissions;
    ProtocolTokenAuthority tokenAuthority;

    function setUp() public {
        tokenAuthority = ProtocolTokenAuthority();
        
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
