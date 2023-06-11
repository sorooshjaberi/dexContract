// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MyDex {
    IERC20 public immutable tokenX;
    IERC20 public immutable tokenY;

    uint256 public lockedX;
    uint256 public lockedY;

    //total shares
    uint256 public totalSupply;
    //balance of shares
    mapping(address => uint256) balances;

    constructor(address _tokenX, address _tokenY) {
        tokenX = IERC20(_tokenX);
        tokenY = IERC20(_tokenY);
    }

    function balanceOf(address _account) public view returns (uint256) {
        return balances[_account];
    }

    function _mint(address _to, uint256 _amount) private {
        balances[_to] += _amount;
        totalSupply += _amount;
    }

    function _burn(address _to, uint256 _amount) private {
        balances[_to] -= _amount;
        totalSupply -= _amount;
    }

    function _update(uint256 _lockedX, uint256 _lockedY) private {
        lockedX = _lockedX;
        lockedY = _lockedY;
    }

    function swap(address _tokenIn, uint256 _amountIn)
        public
        returns (uint256)
    {
        require(
            _tokenIn == address(tokenX) || _tokenIn == address(tokenY),
            "invalid token"
        );
        bool isTokenXIn = _tokenIn == address(tokenX);
        (
            IERC20 tokenIn,
            IERC20 tokenOut,
            uint256 LockedIn,
            uint256 LockedOut
        ) = isTokenXIn
                ? (tokenX, tokenY, lockedX, lockedY)
                : (tokenY, tokenX, lockedY, lockedX);

        uint256 amountInAfterFee = (_amountIn * 997) / 1000;
        uint256 amountOut = (amountInAfterFee * LockedOut) /
            (LockedIn + amountInAfterFee);

        tokenIn.transferFrom(msg.sender, address(this), _amountIn);
        tokenOut.transfer(msg.sender, amountOut);
        _update(
            tokenX.balanceOf(address(this)),
            tokenY.balanceOf(address(this))
        );
        return (amountOut);
    }

    function addLiquidity(uint256 _amountX, uint256 _amountY)
        public
        returns (uint256 shares)
    {
        //transfer tokens to the pool
        tokenX.transferFrom(msg.sender, address(this), _amountX);
        tokenY.transferFrom(msg.sender, address(this), _amountY);

        //not first time ? => adding shouldn't change the price
        if (lockedY > 0 || lockedX > 0) {
            require(
                lockedX * _amountY == lockedY * _amountX,
                "X / Y != dx / dy"
            );
        }

        //mint share tokens (LP tokens) :

        //if user is the first provider => all shares are for the user
        //because it's the first time ,  there are no Locked tokens in the pool so we use sqrt
        //else => we use dx / x * totalSupply
        //we can use either dx/x or dy/y because sooner we checked whether if they are equal

        if (totalSupply == 0) {
            shares = _sqrt(_amountX * _amountY);
        } else {
            shares = (_amountX * totalSupply) / lockedX;
        }

        require(shares > 0, "shares = 0");
        _mint(msg.sender, shares);

        _update(
            tokenX.balanceOf(address(this)),
            tokenY.balanceOf(address(this))
        );
    }

    function removeLiquidity(uint256 _shares)
        public
        returns (uint256 amountX, uint256 amountY)
    {
        require(balanceOf(msg.sender) >= _shares, "insufficient share balance");
        // s / T * (X | Y) = (xOut | yOut)
        amountX = (_shares * lockedX)/ totalSupply;
        amountY = (_shares * lockedY)/ totalSupply;
        require(amountX > 0 && amountY > 0 , "amount x or y is 0");

        _burn(msg.sender, _shares);

        tokenX.transfer(msg.sender, amountX);
        tokenY.transfer(msg.sender, amountY);
        
        _update(tokenX.balanceOf(address(this)), tokenY.balanceOf(address(this)));
    }

    function _sqrt(uint256 y) private pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
