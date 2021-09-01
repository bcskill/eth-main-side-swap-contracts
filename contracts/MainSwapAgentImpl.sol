pragma solidity 0.6.4;

import "./interfaces/IERC20Query.sol";
import "openzeppelin-solidity/contracts/proxy/Initializable.sol";
import "openzeppelin-solidity/contracts/GSN/Context.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

contract MainSwapAgentImpl is Context, Initializable {
    using SafeMath for uint256;

    mapping(address => address) public swapMappingMain2Side;
    mapping(address => address) public swapMappingSide2Main;
    mapping(address => bool) public registeredMain;
    mapping(bytes32 => bool) public filledSideTx;
    mapping(address => uint256) public mainChainErc20Banlance;
    address payable public owner;
    uint256 public swapFee;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event SwapPairRegisterEvent(address indexed sponsor, address indexed mainChainErc20Addr, address indexed sideChainFromAddr, string name, string symbol, uint8 decimals);
    event SwapMain2SideEvent(address indexed sponsor, address indexed mainChainErc20Addr, address indexed sideChainErc20Addr, address sideChainToAddr, uint256 amount, uint256 feeAmount);
    event SwapSide2MainFilledEvent(address indexed mainChainErc20Addr, bytes32 indexed sideChainTxHash, address indexed mainChainToAddr, uint256 amount);
    event RechargeEvent(address indexed mainChainErc20Addr, address indexed sendAddr, uint256 amount);

    constructor() public {
    }

    modifier onlyOwner() {
        require(owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function initialize(uint256 fee, address payable ownerAddr) public {
        swapFee = fee;
        owner = ownerAddr;
    }

    modifier notContract() {
        require(!isContract(msg.sender), "contract is not allowed to swap");
        require(msg.sender == tx.origin, "no proxy contract is allowed");
       _;
    }

    function isContract(address addr) internal view returns (bool) {
        uint size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }

    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }

    function transferOwnership(address payable newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setSwapFee(uint256 fee) onlyOwner external {
        swapFee = fee;
    }

    function registerSwapPairToSide(address mainChainErc20Addr, address sideChainErc20Addr) onlyOwner external returns (bool) {
        require(swapMappingMain2Side[mainChainErc20Addr] == address(0x0), "duplicated main chain swap pair");
        require(swapMappingSide2Main[sideChainErc20Addr] == address(0x0), "duplicated side chain  swap pair");

        string memory name = IERC20Query(mainChainErc20Addr).name();
        string memory symbol = IERC20Query(mainChainErc20Addr).symbol();
        uint8 decimals = IERC20Query(mainChainErc20Addr).decimals();
        require(bytes(name).length>0, "empty name");
        require(bytes(symbol).length>0, "empty symbol");

        swapMappingMain2Side[mainChainErc20Addr] = sideChainErc20Addr;
        swapMappingSide2Main[sideChainErc20Addr] = mainChainErc20Addr;
        mainChainErc20Banlance[mainChainErc20Addr] = 0;

        emit SwapPairRegisterEvent(msg.sender, mainChainErc20Addr, sideChainErc20Addr, name, symbol, decimals);
        return true;
    }

    function fillSide2MainSwap(bytes32 sideChainTxHash, address sideChainErc20Addr, address mainChainToAddr, uint256 amount) onlyOwner external returns (bool) {
        require(!filledSideTx[sideChainTxHash], "side tx filled already");
        address mainChainErc20Addr = swapMappingMain2Side[sideChainErc20Addr];
        require(mainChainErc20Addr != address(0x0), "no swap pair for this token");
        require(IERC20(mainChainErc20Addr).balanceOf(address(this)) >= amount &&
            mainChainErc20Banlance[mainChainErc20Addr] >= amount, "Insufficient contract account balance");

        filledSideTx[sideChainTxHash] = true;
        IERC20(mainChainErc20Addr).transfer(mainChainToAddr, amount);
        mainChainErc20Banlance[mainChainErc20Addr] = mainChainErc20Banlance[mainChainErc20Addr].sub(amount);

        emit SwapSide2MainFilledEvent(mainChainErc20Addr, sideChainTxHash, mainChainToAddr, amount);
        return true;
    }

    function swapMain2Side(address mainChainErc20Addr, address sideChainToAddr, uint256 amount) payable external notContract returns (bool) {
        address sideChainErc20Addr = swapMappingMain2Side[mainChainErc20Addr];
        require(sideChainErc20Addr != address(0x0), "no swap pair for this token");
        require(sideChainToAddr != address(0x0), "sideChainToAddr is error");
        require(amount > 0, "The recharge amount is too small");
        require(IERC20(mainChainErc20Addr).balanceOf(msg.sender) >= amount, "Insufficient contract account balance");
        require(msg.value == swapFee, "swap fee not equal");

        IERC20(mainChainErc20Addr).transferFrom(msg.sender, address(this), amount);
        mainChainErc20Banlance[mainChainErc20Addr] = mainChainErc20Banlance[mainChainErc20Addr].add(amount);
        if (msg.value != 0) {
            owner.transfer(msg.value);
        }

        emit SwapMain2SideEvent(msg.sender, mainChainErc20Addr, sideChainErc20Addr, sideChainToAddr, amount, msg.value);
        return true;
    }
}