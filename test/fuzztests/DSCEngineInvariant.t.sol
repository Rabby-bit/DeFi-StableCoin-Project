//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DeployDSC} from "script/DeployDSC.s.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Handler} from "test/fuzztests/Handler.t.sol";

contract DSCEngineInvariant is StdInvariant {}
