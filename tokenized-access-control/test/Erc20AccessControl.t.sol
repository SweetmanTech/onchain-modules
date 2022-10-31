// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import {DSTest} from "ds-test/test.sol";
import {Vm} from "forge-std/Vm.sol";
import {console} from "forge-std/console.sol";
import {ERC20PresetMinterPauser} from "openzeppelin-contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {ERC20AccessControl} from "../src/ERC20AccessControl.sol";
import {IAccessControlRegistry} from "../src/interfaces/IAccessControlRegistry.sol";
import {MockCurator} from "./MockCurator.sol";

contract ERC20AccessControlTest is DSTest {
    // Init Variables
    ERC20PresetMinterPauser erc20Curator;
    ERC20PresetMinterPauser erc20Manager;
    ERC20PresetMinterPauser erc20Admin;
    Vm public constant vm = Vm(HEVM_ADDRESS);
    address payable public constant DEFAULT_OWNER_ADDRESS =
        payable(address(0x999));
    address payable public constant DEFAULT_NON_OWNER_ADDRESS =
        payable(address(0x888));
    address payable public constant DEFAULT_ADMIN_ADDRESS =
        payable(address(0x777));

    function setUp() public {
        // deploy NFT contract
        vm.startPrank(DEFAULT_OWNER_ADDRESS);
        erc20Curator = new ERC20PresetMinterPauser("20Curator", "20C");
        erc20Manager = new ERC20PresetMinterPauser("20Manager", "20M");
        erc20Admin = new ERC20PresetMinterPauser("20Admin", "20AD");
        erc20Admin.mint(DEFAULT_ADMIN_ADDRESS, 8.08 ether);
        vm.stopPrank();
    }

    function test_initializeWithData() public {
        vm.startPrank(DEFAULT_OWNER_ADDRESS);
        uint256 tokenBalance = 8.08 ether;
        erc20Curator.mint(DEFAULT_OWNER_ADDRESS, tokenBalance);
        ERC20AccessControl e20AccessControl = new ERC20AccessControl();

        bytes memory accessControlInit = abi.encode(
            erc20Curator,
            erc20Manager,
            erc20Admin,
            tokenBalance,
            tokenBalance,
            tokenBalance
        );

        e20AccessControl.initializeWithData(accessControlInit);

        ERC20AccessControl.AccessLevelInfo memory info = e20AccessControl
            .getAccessInfo(DEFAULT_OWNER_ADDRESS);
        assertEq(address(info.curatorAccess), address(erc20Curator));
        assertEq(address(info.managerAccess), address(erc20Manager));
        assertEq(address(info.adminAccess), address(erc20Admin));
        assertEq(info.curatorMinimumBalance, 8.08 ether);
        assertEq(info.managerMinimumBalance, 8.08 ether);
        assertEq(info.adminMinimumBalance, 8.08 ether);
    }

    function test_CuratorAccess() public {
        vm.startPrank(DEFAULT_OWNER_ADDRESS);
        uint256 tokenBalance = 8.08 ether;
        erc20Curator.mint(DEFAULT_OWNER_ADDRESS, tokenBalance);
        ERC20AccessControl e20AccessControl = new ERC20AccessControl();

        MockCurator mockCurator = new MockCurator();
        mockCurator.initializeERC20AccessControl(
            address(e20AccessControl),
            address(erc20Curator),
            address(erc20Manager),
            address(erc20Admin),
            tokenBalance,
            tokenBalance,
            tokenBalance
        );
        vm.stopPrank();
        updateMinimumBalances(e20AccessControl, mockCurator);
        vm.startPrank(DEFAULT_OWNER_ADDRESS);

        assertTrue(
            mockCurator.accessControlProxy() == address(e20AccessControl)
        );
        expectIsCurator(mockCurator);

        erc20Curator.transfer(DEFAULT_NON_OWNER_ADDRESS, tokenBalance);
        expectNoAccess(mockCurator);

        vm.stopPrank();
        vm.startPrank(DEFAULT_NON_OWNER_ADDRESS);

        expectIsCurator(mockCurator);
    }

    function test_ManagerAccess() public {
        vm.startPrank(DEFAULT_OWNER_ADDRESS);
        uint256 tokenBalance = 8.08 ether;
        erc20Manager.mint(DEFAULT_OWNER_ADDRESS, tokenBalance);
        ERC20AccessControl e20AccessControl = new ERC20AccessControl();

        MockCurator mockCurator = new MockCurator();
        mockCurator.initializeERC20AccessControl(
            address(e20AccessControl),
            address(erc20Curator),
            address(erc20Manager),
            address(erc20Admin),
            tokenBalance,
            tokenBalance,
            tokenBalance
        );
        assertTrue(
            mockCurator.accessControlProxy() == address(e20AccessControl)
        );
        vm.stopPrank();
        updateMinimumBalances(e20AccessControl, mockCurator);
        vm.startPrank(DEFAULT_OWNER_ADDRESS);
        expectIsManager(mockCurator);

        erc20Manager.transfer(DEFAULT_NON_OWNER_ADDRESS, tokenBalance);
        expectNoAccess(mockCurator);

        vm.stopPrank();
        vm.startPrank(DEFAULT_NON_OWNER_ADDRESS);
        expectIsManager(mockCurator);
    }

    function test_AdminAccess() public {
        vm.startPrank(DEFAULT_OWNER_ADDRESS);
        uint256 tokenBalance = 8.08 ether;
        erc20Admin.mint(DEFAULT_OWNER_ADDRESS, tokenBalance);
        ERC20AccessControl e20AccessControl = new ERC20AccessControl();

        MockCurator mockCurator = new MockCurator();
        mockCurator.initializeERC20AccessControl(
            address(e20AccessControl),
            address(erc20Curator),
            address(erc20Manager),
            address(erc20Admin),
            tokenBalance,
            tokenBalance,
            tokenBalance
        );
        assertTrue(
            mockCurator.accessControlProxy() == address(e20AccessControl)
        );
        vm.stopPrank();
        updateMinimumBalances(e20AccessControl, mockCurator);
        vm.startPrank(DEFAULT_OWNER_ADDRESS);
        expectIsAdmin(mockCurator);

        erc20Admin.transfer(DEFAULT_NON_OWNER_ADDRESS, tokenBalance);
        expectNoAccess(mockCurator);

        vm.stopPrank();
        vm.startPrank(DEFAULT_NON_OWNER_ADDRESS);

        expectIsAdmin(mockCurator);
    }

    function test_revertUpdateAllAccessByCurator() public {
        vm.startPrank(DEFAULT_OWNER_ADDRESS);
        uint256 tokenBalance = 1 ether;
        erc20Curator.mint(DEFAULT_OWNER_ADDRESS, tokenBalance);
        ERC20AccessControl e20AccessControl = new ERC20AccessControl();
        MockCurator mockCurator = new MockCurator();
        mockCurator.initializeERC20AccessControl(
            address(e20AccessControl),
            address(erc20Curator),
            address(erc20Manager),
            address(erc20Admin),
            tokenBalance,
            tokenBalance,
            tokenBalance
        );
        expectIsCurator(mockCurator);

        vm.expectRevert();
        e20AccessControl.updateAllAccess(
            address(mockCurator),
            erc20Curator,
            erc20Manager,
            erc20Admin,
            8.08 ether,
            8.08 ether,
            8.08 ether
        );
    }

    function test_updateAllAccess() public {
        vm.startPrank(DEFAULT_OWNER_ADDRESS);
        uint256 tokenBalance = 1 ether;
        erc20Admin.mint(DEFAULT_OWNER_ADDRESS, tokenBalance);
        ERC20AccessControl e20AccessControl = new ERC20AccessControl();
        MockCurator mockCurator = new MockCurator();
        mockCurator.initializeERC20AccessControl(
            address(e20AccessControl),
            address(erc20Curator),
            address(erc20Manager),
            address(erc20Admin),
            tokenBalance,
            tokenBalance,
            tokenBalance
        );
        expectIsAdmin(mockCurator);

        e20AccessControl.updateAllAccess(
            address(mockCurator),
            erc20Curator,
            erc20Manager,
            erc20Admin,
            8.08 ether,
            8.08 ether,
            8.08 ether
        );

        ERC20AccessControl.AccessLevelInfo
            memory newAccessLevel = e20AccessControl.getAccessInfo(
                address(mockCurator)
            );
        assertEq(address(newAccessLevel.curatorAccess), address(erc20Curator));
        assertEq(address(newAccessLevel.managerAccess), address(erc20Manager));
        assertEq(address(newAccessLevel.adminAccess), address(erc20Admin));
        assertEq(newAccessLevel.curatorMinimumBalance, 8.08 ether);
        assertEq(newAccessLevel.managerMinimumBalance, 8.08 ether);
        assertEq(newAccessLevel.adminMinimumBalance, 8.08 ether);
        expectNoAccess(mockCurator);
    }

    function test_updateCurator() public {
        vm.startPrank(DEFAULT_OWNER_ADDRESS);
        uint256 tokenBalance = 1 ether;
        erc20Admin.mint(DEFAULT_ADMIN_ADDRESS, tokenBalance);
        erc20Curator.mint(DEFAULT_OWNER_ADDRESS, tokenBalance);
        ERC20AccessControl e20AccessControl = new ERC20AccessControl();
        MockCurator mockCurator = new MockCurator();
        mockCurator.initializeERC20AccessControl(
            address(e20AccessControl),
            address(erc20Curator),
            address(erc20Manager),
            address(erc20Admin),
            1,
            1,
            1
        );
        ERC20AccessControl.AccessLevelInfo
            memory newAccessLevel = e20AccessControl.getAccessInfo(
                address(mockCurator)
            );
        assertEq(address(newAccessLevel.curatorAccess), address(erc20Curator));
        assertEq(newAccessLevel.curatorMinimumBalance, 1);
        expectIsCurator(mockCurator);

        vm.stopPrank();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        e20AccessControl.updateCuratorAccess(
            address(mockCurator),
            erc20Curator,
            8.08 ether
        );
        vm.startPrank(DEFAULT_OWNER_ADDRESS);

        newAccessLevel = e20AccessControl.getAccessInfo(address(mockCurator));
        assertEq(address(newAccessLevel.curatorAccess), address(erc20Curator));
        assertEq(newAccessLevel.curatorMinimumBalance, 8.08 ether);
        expectNoAccess(mockCurator);
    }

    function test_updateManagerAccess() public {
        vm.startPrank(DEFAULT_OWNER_ADDRESS);
        uint256 tokenBalance = 1 ether;
        erc20Admin.mint(DEFAULT_ADMIN_ADDRESS, tokenBalance);
        erc20Manager.mint(DEFAULT_OWNER_ADDRESS, tokenBalance);
        ERC20AccessControl e20AccessControl = new ERC20AccessControl();
        MockCurator mockCurator = new MockCurator();
        mockCurator.initializeERC20AccessControl(
            address(e20AccessControl),
            address(erc20Curator),
            address(erc20Manager),
            address(erc20Admin),
            1,
            1,
            1
        );
        ERC20AccessControl.AccessLevelInfo
            memory newAccessLevel = e20AccessControl.getAccessInfo(
                address(mockCurator)
            );
        assertEq(address(newAccessLevel.managerAccess), address(erc20Manager));
        assertEq(newAccessLevel.managerMinimumBalance, 1);
        expectIsManager(mockCurator);

        vm.stopPrank();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        e20AccessControl.updateManagerAccess(
            address(mockCurator),
            erc20Manager,
            8.08 ether
        );
        vm.startPrank(DEFAULT_OWNER_ADDRESS);

        newAccessLevel = e20AccessControl.getAccessInfo(address(mockCurator));
        assertEq(address(newAccessLevel.managerAccess), address(erc20Manager));
        assertEq(newAccessLevel.managerMinimumBalance, 8.08 ether);
        expectNoAccess(mockCurator);
    }

    function test_updateAdminAccess() public {
        vm.startPrank(DEFAULT_OWNER_ADDRESS);
        uint256 tokenBalance = 1 ether;
        erc20Admin.mint(DEFAULT_OWNER_ADDRESS, tokenBalance);
        ERC20AccessControl e20AccessControl = new ERC20AccessControl();
        MockCurator mockCurator = new MockCurator();
        mockCurator.initializeERC20AccessControl(
            address(e20AccessControl),
            address(erc20Curator),
            address(erc20Manager),
            address(erc20Admin),
            1,
            1,
            1
        );
        ERC20AccessControl.AccessLevelInfo
            memory newAccessLevel = e20AccessControl.getAccessInfo(
                address(mockCurator)
            );
        assertEq(address(newAccessLevel.adminAccess), address(erc20Admin));
        assertEq(newAccessLevel.adminMinimumBalance, 1);
        expectIsAdmin(mockCurator);

        e20AccessControl.updateAdminAccess(
            address(mockCurator),
            erc20Admin,
            8.08 ether
        );

        newAccessLevel = e20AccessControl.getAccessInfo(address(mockCurator));
        assertEq(address(newAccessLevel.adminAccess), address(erc20Admin));
        assertEq(newAccessLevel.adminMinimumBalance, 8.08 ether);
        expectNoAccess(mockCurator);
    }

    function test_getAccessLevel() public {
        vm.startPrank(DEFAULT_OWNER_ADDRESS);
        ERC20AccessControl e20AccessControl = new ERC20AccessControl();
        MockCurator mockCurator = new MockCurator();
        mockCurator.initializeERC20AccessControl(
            address(e20AccessControl),
            address(erc20Curator),
            address(erc20Manager),
            address(erc20Admin),
            1,
            1,
            1
        );
        expectNoAccess(mockCurator);
        erc20Curator.mint(DEFAULT_OWNER_ADDRESS, 1);
        expectIsCurator(mockCurator);
        erc20Manager.mint(DEFAULT_OWNER_ADDRESS, 1);
        expectIsManager(mockCurator);
        erc20Admin.mint(DEFAULT_OWNER_ADDRESS, 1);
        expectIsAdmin(mockCurator);
    }

    //////////////////////////////////////////////////
    // INTERNAL HELPERS
    //////////////////////////////////////////////////
    function expectIsCurator(MockCurator mockCurator) internal {
        assertTrue(mockCurator.getAccessLevelForUser() == 1);
        assertTrue(mockCurator.curatorAccessTest());
        assertTrue(!mockCurator.managerAccessTest());
        assertTrue(!mockCurator.adminAccessTest());
    }

    function expectIsManager(MockCurator mockCurator) internal {
        assertTrue(mockCurator.getAccessLevelForUser() == 2);
        assertTrue(mockCurator.curatorAccessTest());
        assertTrue(mockCurator.managerAccessTest());
        assertTrue(!mockCurator.adminAccessTest());
    }

    function expectIsAdmin(MockCurator mockCurator) internal {
        assertTrue(mockCurator.getAccessLevelForUser() == 3);
        assertTrue(mockCurator.curatorAccessTest());
        assertTrue(mockCurator.managerAccessTest());
        assertTrue(mockCurator.adminAccessTest());
    }

    function expectNoAccess(MockCurator mockCurator) internal {
        assertTrue(mockCurator.getAccessLevelForUser() == 0);
        assertTrue(!mockCurator.curatorAccessTest());
        assertTrue(!mockCurator.managerAccessTest());
        assertTrue(!mockCurator.adminAccessTest());
    }

    function updateMinimumBalances(
        ERC20AccessControl e20AccessControl,
        MockCurator mockCurator
    ) internal {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        e20AccessControl.updateAllAccess(
            address(mockCurator),
            erc20Curator,
            erc20Manager,
            erc20Admin,
            8.08 ether,
            8.08 ether,
            8.08 ether
        );
    }
}
