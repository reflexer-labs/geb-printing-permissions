pragma solidity ^0.6.7;

abstract contract AccountingEngineLike {
    function debtAuctionHouse() virtual public returns (address);
}
abstract contract DebtAuctionHouseLike {
    function AUCTION_HOUSE_TYPE() virtual public returns (bytes32);
    function activeDebtAuctions() virtual public returns (uint256);
}
abstract contract ProtocolTokenAuthorityLike {
    function setRoot(address) virtual public;
    function setOwner(address) virtual public;
    function addAuthorization(address) virtual public;
    function removeAuthorization(address) virtual public;

    function owner() virtual public view returns (address);
    function root() virtual public view returns (address);
}

contract GebPrintingPermissions {
    // --- Auth ---
    mapping (address => uint) public authorizedAccounts;
    /**
     * @notice Add auth to an account
     * @param account Account to add auth to
     */
    function addAuthorization(address account) external emitLog isAuthorized {
        authorizedAccounts[account] = 1;
    }
    /**
     * @notice Remove auth from an account
     * @param account Account to remove auth from
     */
    function removeAuthorization(address account) external emitLog isAuthorized {
        authorizedAccounts[account] = 0;
    }
    /**
    * @notice Checks whether msg.sender can call an authed function
    **/
    modifier isAuthorized {
        require(authorizedAccounts[msg.sender] == 1, "GebPrintingPermissions/account-not-authorized");
        _;
    }

    struct SystemRights {
        bool    covered;
        uint256 revokeRightsDeadline;
        uint256 uncoverCooldownEnd;
        uint256 withdrawAddedRightsDeadline;
        address previousDebtAuctionHouse;
        address currentDebtAuctionHouse;
    }

    mapping(address => SystemRights) public allowedSystems;
    mapping(address => uint256)      public usedAuctionHouses;

    uint256 public unrevokableRightsCooldown;
    uint256 public denyRightsCooldown;
    uint256 public addRightsCooldown;
    uint256 public coveredSystems;

    ProtocolTokenAuthorityLike public protocolTokenAuthority;

    bytes32 public constant AUCTION_HOUSE_TYPE = bytes32("DEBT");

    /**
    * @notice Log an 'anonymous' event with a constant 6 words of calldata
    * and four indexed topics: the selector and the first three args
    **/
    modifier emitLog {
        //
        //
        _;
        assembly {
            let mark := mload(0x40)                   // end of memory ensures zero
            mstore(0x40, add(mark, 288))              // update free memory pointer
            mstore(mark, 0x20)                        // bytes type data offset
            mstore(add(mark, 0x20), 224)              // bytes size (padded)
            calldatacopy(add(mark, 0x40), 0, 224)     // bytes payload
            log4(mark, 288,                           // calldata
                 shl(224, shr(224, calldataload(0))), // msg.sig
                 calldataload(4),                     // arg1
                 calldataload(36),                    // arg2
                 calldataload(68)                     // arg3
                )
        }
    }

    constructor(address protocolTokenAuthority_) public {
        authorizedAccounts[msg.sender] = 1;
        protocolTokenAuthority = ProtocolTokenAuthorityLike(protocolTokenAuthority_);
    }

    // --- Math ---
    function addition(uint x, uint y) internal pure returns (uint z) {
        z = x + y;
        require(z >= x);
    }
    function subtract(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x);
    }

    // --- General Utils ---
    function either(bool x, bool y) internal pure returns (bool z) {
        assembly{ z := or(x, y)}
    }
    function both(bool x, bool y) internal pure returns (bool z) {
        assembly{ z := and(x, y)}
    }

    // --- Administration ---
    /**
     * @notice Modify general uint params
     * @param parameter The name of the parameter modified
     * @param data New value for the parameter
     */
    function modifyParameters(bytes32 parameter, uint data) external emitLog isAuthorized {
        if (parameter == "unrevokableRightsCooldown") unrevokableRightsCooldown = data;
        else if (parameter == "denyRightsCooldown") denyRightsCooldown = data;
        else if (parameter == "addRightsCooldown") addRightsCooldown = data;
        else revert("GebPrintingPermissions/modify-unrecognized-param");
    }

    // --- Token Authority Ownership ---
    function giveUpAuthorityRoot() external emitLog isAuthorized {
        require(protocolTokenAuthority.root() == address(this), "GebPrintingPermissions/not-root");
        protocolTokenAuthority.setRoot(address(0));
    }
    function giveUpAuthorityOwnership() external emitLog isAuthorized {
        require(
          either(
            protocolTokenAuthority.root() == address(this),
            protocolTokenAuthority.owner() == address(this)
          ), "GebPrintingPermissions/not-root-or-owner"
        );
        protocolTokenAuthority.setOwner(address(0));
    }

    // --- Permissions Utils ---
    function revokeDebtAuctionHouses(address accountingEngine) internal {
        address currentHouse  = allowedSystems[accountingEngine].currentDebtAuctionHouse;
        address previousHouse = allowedSystems[accountingEngine].previousDebtAuctionHouse;
        delete allowedSystems[accountingEngine];
        protocolTokenAuthority.removeAuthorization(currentHouse);
        protocolTokenAuthority.removeAuthorization(previousHouse);
    }

    // --- System Cover ---
    function coverSystem(address accountingEngine) external emitLog isAuthorized {
        require(!allowedSystems[accountingEngine].covered, "GebPrintingPermissions/system-already-covered");
        address debtAuctionHouse = AccountingEngineLike(accountingEngine).debtAuctionHouse();
        require(
          keccak256(abi.encode(DebtAuctionHouseLike(debtAuctionHouse).AUCTION_HOUSE_TYPE())) ==
          keccak256(abi.encode(AUCTION_HOUSE_TYPE)),
          "GebPrintingPermissions/not-a-debt-auction-house"
        );
        require(usedAuctionHouses[debtAuctionHouse] == 0, "GebPrintingPermissions/auction-house-already-used");
        usedAuctionHouses[debtAuctionHouse] = 1;
        allowedSystems[accountingEngine] = SystemRights(
          true,
          uint256(-1),
          0,
          addition(now, addRightsCooldown),
          address(0),
          debtAuctionHouse
        );
        coveredSystems = addition(coveredSystems, 1);
        protocolTokenAuthority.addAuthorization(debtAuctionHouse);
    }

    function startUncoverSystem(address accountingEngine) external emitLog isAuthorized {
        require(allowedSystems[accountingEngine].covered, "GebPrintingPermissions/system-not-covered");
        require(allowedSystems[accountingEngine].uncoverCooldownEnd == 0, "GebPrintingPermissions/system-not-being-uncovered");
        require(
          DebtAuctionHouseLike(allowedSystems[accountingEngine].currentDebtAuctionHouse).activeDebtAuctions() == 0,
          "GebPrintingPermissions/ongoing-debt-auctions-current-house"
        );
        if (allowedSystems[accountingEngine].previousDebtAuctionHouse != address(0)) {
          require(
            DebtAuctionHouseLike(allowedSystems[accountingEngine].previousDebtAuctionHouse).activeDebtAuctions() == 0,
            "GebPrintingPermissions/ongoing-debt-auctions-previous-house"
          );
        }
        require(
          either(
            coveredSystems > 1,
            now <= allowedSystems[accountingEngine].withdrawAddedRightsDeadline
          ),
          "GebPrintingPermissions/not-enough-systems-covered"
        );

        if (now <= allowedSystems[accountingEngine].withdrawAddedRightsDeadline) {
          coveredSystems = subtract(coveredSystems, 1);
          usedAuctionHouses[allowedSystems[accountingEngine].previousDebtAuctionHouse] = 0;
          usedAuctionHouses[allowedSystems[accountingEngine].currentDebtAuctionHouse] = 0;
          revokeDebtAuctionHouses(accountingEngine);
        } else {
          require(allowedSystems[accountingEngine].revokeRightsDeadline >= now, "GebPrintingPermissions/revoke-frozen");
          allowedSystems[accountingEngine].uncoverCooldownEnd = addition(now, denyRightsCooldown);
        }
    }

    function abandonUncoverSystem(address accountingEngine) external emitLog isAuthorized {
        require(allowedSystems[accountingEngine].covered, "GebPrintingPermissions/system-not-covered");
        require(allowedSystems[accountingEngine].uncoverCooldownEnd > 0, "GebPrintingPermissions/system-not-being-uncovered");
        allowedSystems[accountingEngine].uncoverCooldownEnd = 0;
    }

    function endUncoverSystem(address accountingEngine) external emitLog isAuthorized {
        require(allowedSystems[accountingEngine].covered, "GebPrintingPermissions/system-not-covered");
        require(allowedSystems[accountingEngine].uncoverCooldownEnd > 0, "GebPrintingPermissions/system-not-being-uncovered");
        require(allowedSystems[accountingEngine].uncoverCooldownEnd < now, "GebPrintingPermissions/cooldown-not-passed");
        require(
          DebtAuctionHouseLike(allowedSystems[accountingEngine].currentDebtAuctionHouse).activeDebtAuctions() == 0,
          "GebPrintingPermissions/ongoing-debt-auctions-current-house"
        );
        if (allowedSystems[accountingEngine].previousDebtAuctionHouse != address(0)) {
          require(
            DebtAuctionHouseLike(allowedSystems[accountingEngine].previousDebtAuctionHouse).activeDebtAuctions() == 0,
            "GebPrintingPermissions/ongoing-debt-auctions-previous-house"
          );
        }
        require(
          either(
            coveredSystems > 1,
            now <= allowedSystems[accountingEngine].withdrawAddedRightsDeadline
          ),
          "GebPrintingPermissions/not-enough-systems-covered"
        );

        usedAuctionHouses[allowedSystems[accountingEngine].previousDebtAuctionHouse] = 0;
        usedAuctionHouses[allowedSystems[accountingEngine].currentDebtAuctionHouse]  = 0;

        allowedSystems[accountingEngine].covered = false;
        coveredSystems = subtract(coveredSystems, 1);
        revokeDebtAuctionHouses(accountingEngine);
        delete allowedSystems[accountingEngine];
    }

    function updateCurrentDebtAuctionHouse(address accountingEngine) external emitLog isAuthorized {
        require(allowedSystems[accountingEngine].covered, "GebPrintingPermissions/system-not-covered");
        address newHouse = AccountingEngineLike(accountingEngine).debtAuctionHouse();
        require(newHouse != allowedSystems[accountingEngine].currentDebtAuctionHouse, "GebPrintingPermissions/new-house-not-changed");
        require(
          keccak256(abi.encode(DebtAuctionHouseLike(newHouse).AUCTION_HOUSE_TYPE())) ==
          keccak256(abi.encode(AUCTION_HOUSE_TYPE)),
          "GebPrintingPermissions/new-house-not-a-debt-auction"
        );
        require(allowedSystems[accountingEngine].previousDebtAuctionHouse == address(0), "GebPrintingPermissions/previous-house-not-removed");
        require(usedAuctionHouses[newHouse] == 0, "GebPrintingPermissions/auction-house-already-used");
        usedAuctionHouses[newHouse] = 1;
        allowedSystems[accountingEngine].previousDebtAuctionHouse =
          allowedSystems[accountingEngine].currentDebtAuctionHouse;
        allowedSystems[accountingEngine].currentDebtAuctionHouse = newHouse;
        protocolTokenAuthority.addAuthorization(newHouse);
    }

    function removePreviousDebtAuctionHouse(address accountingEngine) external emitLog isAuthorized {
        require(allowedSystems[accountingEngine].covered, "GebPrintingPermissions/system-not-covered");
        require(
          allowedSystems[accountingEngine].previousDebtAuctionHouse != address(0),
          "GebPrintingPermissions/inexistent-previous-auction-house"
        );
        require(
          DebtAuctionHouseLike(allowedSystems[accountingEngine].previousDebtAuctionHouse).activeDebtAuctions() == 0,
          "GebPrintingPermissions/ongoing-debt-auctions-previous-house"
        );
        address previousHouse = allowedSystems[accountingEngine].previousDebtAuctionHouse;
        usedAuctionHouses[previousHouse] = 0;
        allowedSystems[accountingEngine].previousDebtAuctionHouse = address(0);
        protocolTokenAuthority.removeAuthorization(previousHouse);
    }

    function proposeIndefinitePrintingPermissions(address accountingEngine, uint256 freezeDelay) external emitLog isAuthorized {
        require(allowedSystems[accountingEngine].covered, "GebPrintingPermissions/system-not-covered");
        require(both(freezeDelay >= unrevokableRightsCooldown, freezeDelay > 0), "GebPrintingPermissions/low-delay");
        require(allowedSystems[accountingEngine].revokeRightsDeadline > addition(now, freezeDelay), "GebPrintingPermissions/big-delay");
        allowedSystems[accountingEngine].revokeRightsDeadline = addition(now, freezeDelay);
    }
}
