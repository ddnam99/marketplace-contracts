// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2;

library AddressesLib {
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

    function exists(address[] storage self, address element) internal view returns (bool) {
        for (uint256 i = 0; i < self.length; i++) {
            if (self[i] == element) return true;
        }
        return false;
    }
}
