// SPDX-License-Identifier: Apache-2.0
pragma solidity =0.8.27;

// OpenZeppelin dependencies
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title TokenVesting
 */
contract Vesting is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @dev Struct containing the vesting schedule information
    struct VestingSchedule {
        /// @dev Beneficiary of tokens after they are released
        address beneficiary;
        /// @dev Cliff time of the vesting start in seconds since the UNIX epoch
        uint256 cliff;
        /// @dev Start time of the vesting period in seconds since the UNIX epoch
        uint256 start;
        /// @dev Duration of the vesting period in seconds
        uint256 duration;
        /// @dev Duration of a slice period for the vesting in seconds
        uint256 slicePeriodSeconds;
        /// @dev Whether or not the vesting is revocable
        bool revocable;
        /// @dev Total amount of tokens to be released at the end of the vesting
        uint256 amountTotal;
        /// @dev Amount of tokens released
        uint256 released;
        /// @dev Whether or not the vesting has been revoked
        bool revoked;
    }

    /// @notice Address of the ERC20 token
    IERC20 public immutable token;

    /// @notice List of vesting schedules
    bytes32[] public vestingSchedulesIds;

    /// @notice Mapping from schedule id to vesting schedule
    mapping(bytes32 => VestingSchedule) public vestingSchedules;

    /// @notice Total amount of tokens in the contract to be released
    uint256 public vestingSchedulesTotalAmount;

    /// @notice Mapping from owner address to number of vesting schedules currently being vested
    mapping(address => uint256) public holdersVestingCount;

    /// @notice Emitted when new vesting schedule has been created
    event VestingScheduleCreated(
        address indexed benificiary,
        uint256 start,
        uint256 cliff,
        uint256 duration,
        uint256 slicePeriodSeconds,
        bool revocable,
        uint256 amount,
        bytes32 vestingScheduleId
    );

    /// @notice Emitted when vesting schedule has released token
    event VestingScheduleReleased(bytes32 indexed vestingScheduleId, uint256 amount);

    /// @notice Emitted when vesting schedule has been revoked
    event VestingScheduleRevoked(bytes32 indexed vestingScheduleId);

    /// @notice Emitted when token withdrawn
    event TokenWithdrawn(address indexed reciever, uint256 amount);

    /// @notice Token address is zero
    error ZeroTokenAddress();

    /// @notice Schedule has been revoked
    error ScheduleRevoked();

    /// @notice Zero address
    error ZeroAddress();

    /// @notice Start time is before current time
    error StartLessThanCurrent();

    /// @notice Insufficient amount of tokens
    error InsufficientAmount();

    /// @notice Zero duration
    error ZeroDuration();

    /// @notice Zero amount
    error ZeroAmount();

    /// @notice Zero slice periods
    error ZeroSlicePeriods();

    /// @notice Slice period is greater than duration
    error SlicePeriodGreaterThanDuration();

    /// @notice Duration is less than the cliff
    /// @param duration vesting duration in seconds
    /// @param cliff cliff period in seconds
    error DurationLessThanCliff(uint256 duration, uint256 cliff);

    /// @notice Schedule is not revocable
    error ScheduleNotRevocable();

    /// @notice Operation forbidden
    error Forbidden();

    /**
     * @dev Reverts if the vesting schedule does not exist or has been revoked.
     */
    modifier onlyIfVestingScheduleNotRevoked(bytes32 vestingScheduleId) {
        require(!vestingSchedules[vestingScheduleId].revoked, ScheduleRevoked());
        _;
    }

    /**
     * @dev Creates a vesting contract.
     * @param token_ address of the ERC20 token contract
     */
    constructor(IERC20 token_) Ownable(msg.sender) {
        // Check that the token address is not 0x0.
        require(token_ != IERC20(address(0x0)), ZeroTokenAddress());
        // Set the token address.
        token = token_;
    }

    /**
     * @notice Creates a new vesting schedule for a beneficiary.
     * @param _beneficiary address of the beneficiary to whom vested tokens are transferred
     * @param _start start time of the vesting period
     * @param _cliff duration in seconds of the cliff in which tokens will begin to vest
     * @param _duration duration in seconds of the period in which the tokens will vest
     * @param _slicePeriodSeconds duration of a slice period for the vesting in seconds
     * @param _revocable whether the vesting is revocable or not
     * @param _amount total amount of tokens to be released at the end of the vesting
     */
    function createVestingSchedule(
        address _beneficiary,
        uint256 _start,
        uint256 _cliff,
        uint256 _duration,
        uint256 _slicePeriodSeconds,
        bool _revocable,
        uint256 _amount
    ) external onlyOwner returns (bytes32){
        require(_beneficiary != address(0), ZeroAddress());
        require(_start >= block.timestamp, StartLessThanCurrent());
        require(getWithdrawableAmount() >= _amount, InsufficientAmount());
        require(_duration > 0, ZeroDuration());
        require(_amount > 0, ZeroAmount());
        require(_slicePeriodSeconds >= 1, ZeroSlicePeriods());
        require(_slicePeriodSeconds <= _duration, SlicePeriodGreaterThanDuration());
        require(_duration >= _cliff, DurationLessThanCliff(_duration, _cliff));
        bytes32 vestingScheduleId = computeNextVestingScheduleIdForHolder(
            _beneficiary
        );
        uint256 cliff = _start + _cliff;
        vestingSchedules[vestingScheduleId] = VestingSchedule(
            _beneficiary,
            cliff,
            _start,
            _duration,
            _slicePeriodSeconds,
            _revocable,
            _amount,
            0,
            false
        );
        vestingSchedulesTotalAmount = vestingSchedulesTotalAmount + _amount;
        vestingSchedulesIds.push(vestingScheduleId);
        uint256 currentVestingCount = holdersVestingCount[_beneficiary];
        holdersVestingCount[_beneficiary] = currentVestingCount + 1;

        emit VestingScheduleCreated(
            _beneficiary,
            _start,
            _cliff,
            _duration,
            _slicePeriodSeconds,
            _revocable,
            _amount,
            vestingScheduleId
        );

        return vestingScheduleId;
    }

    /**
     * @notice Revokes the vesting schedule for given identifier.
     * @param vestingScheduleId the vesting schedule identifier
     */
    function revoke(
        bytes32 vestingScheduleId
    ) external onlyOwner onlyIfVestingScheduleNotRevoked(vestingScheduleId) {
        VestingSchedule storage vestingSchedule = vestingSchedules[vestingScheduleId];
        require(
            vestingSchedule.revocable,
            ScheduleNotRevocable()
        );
        uint256 vestedAmount = _computeReleasableAmount(vestingSchedule);
        if (vestedAmount > 0) {
            release(vestingScheduleId, vestedAmount);
        }
        uint256 unreleased = vestingSchedule.amountTotal - vestingSchedule.released;
        vestingSchedulesTotalAmount = vestingSchedulesTotalAmount - unreleased;
        vestingSchedule.revoked = true;

        emit VestingScheduleRevoked(vestingScheduleId);
    }

    /**
     * @notice Withdraw the specified amount if possible.
     * @param amount the amount to withdraw
     */
    function withdraw(uint256 amount) external nonReentrant onlyOwner {
        require(getWithdrawableAmount() >= amount, InsufficientAmount());
        token.safeTransfer(msg.sender, amount);

        emit TokenWithdrawn(msg.sender, amount);
    }

    /**
     * @notice Release vested amount of tokens.
     * @param vestingScheduleId the vesting schedule identifier
     * @param amount the amount to release
     */
    function release(
        bytes32 vestingScheduleId,
        uint256 amount
    ) public nonReentrant onlyIfVestingScheduleNotRevoked(vestingScheduleId) {
        VestingSchedule storage vestingSchedule = vestingSchedules[vestingScheduleId];
        bool isBeneficiary = (msg.sender == vestingSchedule.beneficiary);
        bool isReleasor = (msg.sender == owner());
        require(isBeneficiary || isReleasor, Forbidden());
        uint256 vestedAmount = _computeReleasableAmount(vestingSchedule);
        require(vestedAmount >= amount, InsufficientAmount());

        vestingSchedule.released = vestingSchedule.released + amount;
        vestingSchedulesTotalAmount = vestingSchedulesTotalAmount - amount;

        token.safeTransfer(vestingSchedule.beneficiary, amount);

        emit VestingScheduleReleased(vestingScheduleId, amount);
    }

    /**
     * @dev Returns the number of vesting schedules managed by this contract.
     * @return the number of vesting schedules
     */
    function getVestingSchedulesCount() public view returns (uint256) {
        return vestingSchedulesIds.length;
    }

    /**
     * @notice Computes the vested amount of tokens for the given vesting schedule identifier.
     * @return the vested amount
     */
    function computeReleasableAmount(bytes32 vestingScheduleId)
    external
    view
    onlyIfVestingScheduleNotRevoked(vestingScheduleId)
    returns (uint256)
    {
        VestingSchedule storage vestingSchedule = vestingSchedules[vestingScheduleId];
        return _computeReleasableAmount(vestingSchedule);
    }

    /**
     * @dev Returns the amount of tokens that can be withdrawn by the owner.
     * @return the amount of tokens
     */
    function getWithdrawableAmount() public view returns (uint256) {
        return token.balanceOf(address(this)) - vestingSchedulesTotalAmount;
    }

    /**
     * @dev Computes the next vesting schedule identifier for a given holder address.
     */
    function computeNextVestingScheduleIdForHolder(
        address holder
    ) internal view returns (bytes32) {
        return computeVestingScheduleIdForAddressAndIndex(holder, holdersVestingCount[holder]);
    }

    /**
     * @dev Returns the last vesting schedule for a given holder address.
     */
    function getLastVestingScheduleForHolder(
        address holder
    ) external view returns (VestingSchedule memory) {
        return vestingSchedules[computeVestingScheduleIdForAddressAndIndex(holder, holdersVestingCount[holder] - 1)];
    }

    /**
     * @dev Computes the vesting schedule identifier for an address and an index.
     */
    function computeVestingScheduleIdForAddressAndIndex(
        address holder,
        uint256 index
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(holder, index));
    }

    /**
     * @dev Computes the releasable amount of tokens for a vesting schedule.
     * @return the amount of releasable tokens
     */
    function _computeReleasableAmount(
        VestingSchedule memory vestingSchedule
    ) internal view returns (uint256) {
        // Retrieve the current time.
        uint256 currentTime = getCurrentTime();
        // If the current time is before the cliff, no tokens are releasable.
        if ((currentTime < vestingSchedule.cliff) || vestingSchedule.revoked) {
            return 0;
        } else if (currentTime >= vestingSchedule.cliff + vestingSchedule.duration) {
            // If the current time is after the vesting period, all tokens are releasable,
            // minus the amount already released.
            return vestingSchedule.amountTotal - vestingSchedule.released;
        } else {
            // Otherwise, some tokens are releasable.
            // Compute the number of full vesting periods that have elapsed.
            uint256 timeFromStart = currentTime - vestingSchedule.cliff;
            uint256 secondsPerSlice = vestingSchedule.slicePeriodSeconds;
            uint256 vestedSlicePeriods = timeFromStart / secondsPerSlice;
            uint256 vestedSeconds = vestedSlicePeriods * secondsPerSlice;
            // Compute the amount of tokens that are vested.
            uint256 vestedAmount = (vestingSchedule.amountTotal *
                vestedSeconds) / vestingSchedule.duration;
            // Subtract the amount already released and return.
            return vestedAmount - vestingSchedule.released;
        }
    }

    /**
     * @dev Returns the current time.
     * @return the current timestamp in seconds.
     */
    function getCurrentTime() internal view virtual returns (uint256) {
        return block.timestamp;
    }
}