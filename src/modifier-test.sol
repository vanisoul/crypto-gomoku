// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ModifiersExecution {
    uint256 public modState1;
    uint256 public modState2;
    uint256 public modState3;

    event ModifierExecuted(string modifierName, uint256 state1, uint256 state2, uint256 state3);

    modifier modA() {
        modState1 = modState1 + 1;
        emit ModifierExecuted("modA", modState1, modState2, modState3);
        _;
    }

    modifier modB() {
        modState2 = modState2 + 1;
        emit ModifierExecuted("modB_1", modState1, modState2, modState3);
        _;
        modState2 = modState2 + 1;
        emit ModifierExecuted("modB_2", modState1, modState2, modState3);
        _;
    }

    function func() public modA modB {
        modState3 = modState3 + 1;
        emit ModifierExecuted("func", modState1, modState2, modState3);
    }
}

// emit ModifierExecuted("modA", modState1, modState2, modState3);
// emit ModifierExecuted("modB_1", modState1, modState2, modState3);
// emit ModifierExecuted("func", modState1, modState2, modState3);
// emit ModifierExecuted("modB_2", modState1, modState2, modState3);
// emit ModifierExecuted("func", modState1, modState2, modState3);

// 修飾符 是方法 倒序代入到 _ 完成取代過程
