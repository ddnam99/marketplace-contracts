// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2;

library AddressesLib {
    function find(uint256[] memory array, uint256 value) internal pure returns (uint256, bool) {
        require(array.length > 0, "Array is empty");
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == value) {
                return (i, true);
            }
        }
        return (0, false);
    }

    function remove(address[] storage self, address element) internal returns (bool) {
        for (uint256 i = 0; i < self.length; i++) {
            if (self[i] == element) {
                self[i] = self[self.length - 1];
                self.pop();
                return true;
            }
        }
        return false;
    }

    function removeAtIndex(uint256[] storage array, uint256 index) internal {
        require(array.length > index, "Invalid index");

        if (array.length > 1) {
            array[index] = array[array.length - 1];
        }

        array.pop();
    }

    function exists(address[] storage self, address element) internal view returns (bool) {
        for (uint256 i = 0; i < self.length; i++) {
            if (self[i] == element) return true;
        }
        return false;
    }
}
