pragma solidity 0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _setOwner(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface ILiquidityPoolManagerV2 {
    function stakes(address pair) external view returns (address);
}

interface IHoneyPair {
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
}

interface IHoneyERC20 {
    function balanceOf(address owner) external view returns (uint);
    function getCurrentVotes(address account) external view returns (uint);
    function delegates(address account) external view returns (address);
}

interface IStakingRewards {
    function rewardsToken() external view returns (address);
    function stakingToken() external view returns (address);
    function balanceOf(address owner) external view returns (uint);
    function earned(address account) external view returns (uint);
}

// SPDX-License-Identifier: GPL-3.0-or-later
contract HoneyVoteCalculator is Ownable {

    IHoneyERC20 honey;
    ILiquidityPoolManagerV2 liquidityManager;

    constructor(address _honey, address _liquidityManager) {
        honey = IHoneyERC20(_honey);
        liquidityManager = ILiquidityPoolManagerV2(_liquidityManager);
    }

    function getVotesFromFarming(address voter, address[] calldata farms) external view returns (uint votes) {
        for (uint i; i<farms.length; i++) {
            IHoneyPair pair = IHoneyPair(farms[i]);
            IStakingRewards staking = IStakingRewards(liquidityManager.stakes(farms[i]));

            // Handle pairs that are no longer whitelisted
            if (address(staking) == address(0)) continue;

            uint pair_total_HONEY = honey.balanceOf(farms[i]);
            uint pair_total_HLP = pair.totalSupply(); // Could initially be 0 in rare situations

            uint HLP_hodling = pair.balanceOf(voter);
            uint HLP_staking = staking.balanceOf(voter);

            uint pending_HONEY = staking.earned(voter);

            votes += ((HLP_hodling + HLP_staking) * pair_total_HONEY) / pair_total_HLP + pending_HONEY;
        }
    }

    function getVotesFromStaking(address voter, address[] calldata stakes) external view returns (uint votes) {
        for (uint i; i<stakes.length; i++) {
            IStakingRewards staking = IStakingRewards(stakes[i]);

            uint staked_HONEY = staking.stakingToken() == address(honey) ? staking.balanceOf(voter) : uint(0);

            uint pending_HONEY = staking.rewardsToken() == address(honey) ? staking.earned(voter) : uint(0);

            votes += (staked_HONEY + pending_HONEY);
        }
    }

    function getVotesFromWallets(address voter) external view returns (uint votes) {
        // Votes delegated to the voter
        votes += honey.getCurrentVotes(voter);

        // Voter has never delegated
        if (honey.delegates(voter) == address(0)) {
            votes += honey.balanceOf(voter);
        }
    }

    function changeLiquidityPoolManager(address _liquidityManager) external onlyOwner {
        liquidityManager = ILiquidityPoolManagerV2(_liquidityManager);
    }

}