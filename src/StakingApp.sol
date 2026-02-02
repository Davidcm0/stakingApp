//SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
//Staking fixed amount. Ej: 10 tokens
//Staking reward period: 

contract StakingApp is Ownable {
    //OTRA MEJORA: HACERLO CON REWARD VARIABLE SEGUN EL TIEMPO STAKEADO
    //OTRA MEJORA: HACERLO CON UN SISTEMA DE NIVELES DE STAKING SEGUN LA CANTIDAD STAKEADA
    //OTRA MEJORA: HACERLO CON UN SISTEMA DE PENALIZACIONES POR RETIRADAS ANTICIPADAS
    //OTRA MEJORA: HACERLO CON POSIBILIDAD DE STAKEAR DISTINTAS CANTIDADES
    //OTRA MEJORA: HACERLO CON UN PERIODO MINIMO Y MAXIMO DE STAKING
    //MEJORA: HACERLO CON UN ARRAY DE STAKERS PARA PODER ITERAR SOBRE ELLOS Y HACER REPARTOS DE RECOMPENSAS MASIVOS
    //OTRA MEJORA: HACERLO CON UN TOKEN ERC20 DE RECOMPENSAS EN LUGAR DE ETHER
    //OTRA MEJORA: HACERLO CON POSIBILIDAD DE ACUMULAR RECOMPENSAS SI SE ESPERA MAS DEL PERIODO
    //OTRA MEJORA: HACERLO CON UN SISTEMA DE BONIFICACIONES POR STAKING PROLONGADO

    //1. Staking token address
    address public stakingToken;
    uint256 public stakingPeriod; //in seconds,
    uint256 public fixedStakingAmount;
    uint256 public rewardPerPeriod; //fixed reward per staking period, 
    mapping(address => uint256) public stakingBalance;
    mapping(address => uint256) public stakingTimestamp;

    event SetStakingPeriod(uint256 newStakingPeriod, address indexed owner);
    event Staked(uint256 amountStaked, address indexed staker);
    event Withdraw(uint256 amountWithdrawn, address indexed staker);
    event EtherReceived(address indexed sender, uint256 amount);

    constructor(address stakingToken_, address owner_, uint256 stakingPeriod_, uint256 fixedStakingAmount_, uint256 rewardPerPeriod_) Ownable(owner_) {
        stakingToken = stakingToken_;
        stakingPeriod = stakingPeriod_;
        fixedStakingAmount = fixedStakingAmount_;
        rewardPerPeriod = rewardPerPeriod_;
    }

    function setStakingPeriod(uint256 newStakingPeriod) external onlyOwner() {
        stakingPeriod = newStakingPeriod;
        emit SetStakingPeriod(newStakingPeriod, msg.sender);
    }
    
    function depositStake(uint256 tokenAmountToDeposit_) external {
        //para transferir los tokens, dos funciones:
        //funcion transfer: msg.sender transfiere los tokens al contrato
        //funcion transferFrom: el contrato transfiere los tokens de msg.sender al contrato. 
        //Tiene el poder de coger los fondes de una EOA y enviarlo a este smart contract o a otro o a otro usuario.
        //para usar transferFrom, primero msg.sender debe aprobar al contrato para que pueda transferir
        require(tokenAmountToDeposit_ == fixedStakingAmount, "Incorrect staking amount");
        require(stakingBalance[msg.sender] == 0, "Already staking");
        bool success = IERC20(address(stakingToken)).transferFrom(msg.sender, address(this), tokenAmountToDeposit_);
        require(success, "Token transfer failed");
        stakingBalance[msg.sender] += tokenAmountToDeposit_;
        stakingTimestamp[msg.sender] = block.timestamp;
        emit Staked(tokenAmountToDeposit_, msg.sender);
    }

    function withdrawStake() external {
        //aqui se sigue CEI pattern porque hay una transferencia de tokens, pero porque? porque si la transferencia falla, no queremos que se modifique el estado del contrato
        //mentira porque estamos trabajando con token ERC20, entonces no habrá ningún receive ether, pero es buena práctica seguir CEI pattern.
        //Checks
        require(stakingBalance[msg.sender] > 0, "No stake to withdraw");
        //Effects
        uint256 amountToWithdraw = stakingBalance[msg.sender];
        stakingBalance[msg.sender] = 0;
        //Interactions
        bool success = IERC20(address(stakingToken)).transfer(msg.sender, amountToWithdraw);
        require(success, "Token transfer failed");
        emit Withdraw(amountToWithdraw, msg.sender);
    }

    function claimRewards() external {
        //Check the balance staked
        require(stakingBalance[msg.sender] > 0, "No stake to claim reward");
        //Calculate if the staking period has elapsed
        uint256 elapsedPeriod = block.timestamp - stakingTimestamp[msg.sender];
        require(elapsedPeriod >= stakingPeriod, "Staking period not yet elapsed");
        //effects
        //update the timestamp to avoid multiple claims without staking again
        stakingTimestamp[msg.sender] = block.timestamp;
        //interactions
        //Transfer the rewards
        (bool success,) = msg.sender.call {value: rewardPerPeriod}("");
        require(success, "Reward transfer failed");

    }

    receive() external payable onlyOwner() {
        //función receive para recibir ethers
        //esto ahora lo mismo
        emit EtherReceived(msg.sender, msg.value);
    }
}