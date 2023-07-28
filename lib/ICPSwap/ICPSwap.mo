// Pools: 4mmnk-kiaaa-aaaag-qbllq-cai
// Pair(SNS1): 3ejs3-eaaaa-aaaag-qbl2a-cai
module {
  public type AccountBalance = { balance0 : Nat; balance1 : Nat };
  public type ClaimArgs = { operator : Principal; positionId : Nat };
  public type CycleInfo = { balance : Nat; available : Nat };
  public type DecreaseLiquidityArgs = {
    operator : Principal;
    liquidity : Text;
    amount0Min : Text;
    amount1Min : Text;
    positionId : Nat;
  };
  public type DepositArgs = { token : Text; amount : Nat };
  public type Error = {
    #CommonError;
    #InternalError : Text;
    #UnsupportedToken : Text;
    #InsufficientFunds;
  };
  public type GetPositionArgs = { tickUpper : Int; tickLower : Int };
  public type IncreaseLiquidityArgs = {
    operator : Principal;
    amount0Min : Text;
    amount1Min : Text;
    positionId : Nat;
    amount0Desired : Text;
    amount1Desired : Text;
  };
  public type MintArgs = {
    fee : Nat;
    tickUpper : Int;
    operator : Principal;
    amount0Min : Text;
    amount1Min : Text;
    token0 : Text;
    token1 : Text;
    amount0Desired : Text;
    amount1Desired : Text;
    tickLower : Int;
  };
  public type Page = {
    content : [UserPositionInfoWithId];
    offset : Nat;
    limit : Nat;
    totalElements : Nat;
  };
  public type Page_1 = {
    content : [UserPositionInfoWithTokenAmount];
    offset : Nat;
    limit : Nat;
    totalElements : Nat;
  };
  public type Page_2 = {
    content : [TickInfoWithId];
    offset : Nat;
    limit : Nat;
    totalElements : Nat;
  };
  public type Page_3 = {
    content : [TickLiquidityInfo];
    offset : Nat;
    limit : Nat;
    totalElements : Nat;
  };
  public type Page_4 = {
    content : [PositionInfoWithId];
    offset : Nat;
    limit : Nat;
    totalElements : Nat;
  };
  public type Page_5 = {
    content : [(Principal, AccountBalance)];
    offset : Nat;
    limit : Nat;
    totalElements : Nat;
  };
  public type PoolMetadata = {
    fee : Nat;
    key : Text;
    sqrtPriceX96 : Nat;
    tick : Int;
    liquidity : Nat;
    token0 : Token;
    token1 : Token;
    maxLiquidityPerTick : Nat;
  };
  public type PositionInfo = {
    tokensOwed0 : Nat;
    tokensOwed1 : Nat;
    feeGrowthInside1LastX128 : Nat;
    liquidity : Nat;
    feeGrowthInside0LastX128 : Nat;
  };
  public type PositionInfoWithId = {
    id : Text;
    tokensOwed0 : Nat;
    tokensOwed1 : Nat;
    feeGrowthInside1LastX128 : Nat;
    liquidity : Nat;
    feeGrowthInside0LastX128 : Nat;
  };
  public type PushError = { time : Int; message : Text };
  public type Result = { #ok : Nat; #err : Error };
  public type Result_1 = { #ok : Int; #err : Error };
  public type Result_10 = { #ok : Page_2; #err : Error };
  public type Result_11 = { #ok : Page_3; #err : Error };
  public type Result_12 = { #ok : State; #err : Error };
  public type Result_13 = { #ok : Principal; #err : Error };
  public type Result_14 = { #ok : Page_4; #err : Error };
  public type Result_15 = { #ok : PositionInfo; #err : Error };
  public type Result_16 = { #ok : CycleInfo; #err : Error };
  public type Result_17 = {
    #ok : {
      nftCid : Text;
      infoCid : Text;
      ticketCid : Text;
      scheduleCid : Text;
    };
    #err : Error;
  };
  public type Result_18 = { #ok : [(Text, Principal)]; #err : Error };
  public type Result_19 = {
    #ok : { amount0 : Nat; amount1 : Nat };
    #err : Error;
  };
  public type Result_2 = {
    #ok : SnapshotCumulativesInsideResult;
    #err : Error;
  };
  public type Result_20 = {
    #ok : {
      tokenIncome : [(Nat, { tokensOwed0 : Nat; tokensOwed1 : Nat })];
      totalTokensOwed0 : Nat;
      totalTokensOwed1 : Nat;
    };
    #err : Error;
  };
  public type Result_21 = { #ok : Page_5; #err : Error };
  public type Result_3 = {
    #ok : { tokensOwed0 : Nat; tokensOwed1 : Nat };
    #err : Error;
  };
  public type Result_4 = { #ok : PoolMetadata; #err : Error };
  public type Result_5 = {
    #ok : { balance0 : Nat; balance1 : Nat };
    #err : Error;
  };
  public type Result_6 = { #ok : Page; #err : Error };
  public type Result_7 = { #ok : Page_1; #err : Error };
  public type Result_8 = { #ok : UserPositionInfo; #err : Error };
  public type Result_9 = {
    #ok : {
      swapFee0Repurchase : Nat;
      token0Amount : Nat;
      token1Amount : Nat;
      swapFee1Repurchase : Nat;
    };
    #err : Error;
  };
  public type SnapshotCumulativesInsideArgs = {
    tickUpper : Int;
    tickLower : Int;
  };
  public type SnapshotCumulativesInsideResult = {
    tickCumulativeInside : Int;
    secondsPerLiquidityInsideX128 : Nat;
    secondsInside : Nat;
  };
  public type State = {
    infoCid : Text;
    records : [SwapRecordInfo];
    errors : [PushError];
    retryCount : Nat;
    infoCanisterAvailable : Bool;
  };
  public type SwapArgs = {
    operator : Principal;
    amountIn : Text;
    zeroForOne : Bool;
    amountOutMinimum : Text;
  };
  public type SwapRecordInfo = {
    to : Text;
    feeAmount : Int;
    action : TransactionType;
    feeAmountTotal : Int;
    token0Id : Text;
    token1Id : Text;
    token0AmountTotal : Nat;
    liquidityTotal : Nat;
    from : Text;
    tick : Int;
    feeTire : Nat;
    recipient : Text;
    token0ChangeAmount : Nat;
    token1AmountTotal : Nat;
    liquidityChange : Nat;
    token1Standard : Text;
    TVLToken0 : Int;
    TVLToken1 : Int;
    token0Fee : Nat;
    token1Fee : Nat;
    timestamp : Int;
    token1ChangeAmount : Nat;
    token0Standard : Text;
    price : Nat;
    poolId : Text;
  };
  public type TickInfoWithId = {
    id : Text;
    initialized : Bool;
    feeGrowthOutside1X128 : Nat;
    secondsPerLiquidityOutsideX128 : Nat;
    liquidityNet : Int;
    secondsOutside : Nat;
    liquidityGross : Nat;
    feeGrowthOutside0X128 : Nat;
    tickCumulativeOutside : Int;
  };
  public type TickLiquidityInfo = {
    tickIndex : Int;
    price0Decimal : Nat;
    liquidityNet : Int;
    price0 : Nat;
    price1 : Nat;
    liquidityGross : Nat;
    price1Decimal : Nat;
  };
  public type Token = { address : Text; standard : Text };
  public type TransactionType = {
    #decreaseLiquidity;
    #claim;
    #swap;
    #addLiquidity;
    #increaseLiquidity;
  };
  public type UserPositionInfo = {
    tickUpper : Int;
    tokensOwed0 : Nat;
    tokensOwed1 : Nat;
    feeGrowthInside1LastX128 : Nat;
    liquidity : Nat;
    feeGrowthInside0LastX128 : Nat;
    tickLower : Int;
  };
  public type UserPositionInfoWithId = {
    id : Nat;
    tickUpper : Int;
    tokensOwed0 : Nat;
    tokensOwed1 : Nat;
    feeGrowthInside1LastX128 : Nat;
    liquidity : Nat;
    feeGrowthInside0LastX128 : Nat;
    tickLower : Int;
  };
  public type UserPositionInfoWithTokenAmount = {
    id : Nat;
    tickUpper : Int;
    tokensOwed0 : Nat;
    tokensOwed1 : Nat;
    feeGrowthInside1LastX128 : Nat;
    liquidity : Nat;
    feeGrowthInside0LastX128 : Nat;
    token0Amount : Nat;
    token1Amount : Nat;
    tickLower : Int;
  };
  public type Value = { #Int : Int; #Nat : Nat; #Blob : Blob; #Text : Text };
  public type WithdrawArgs = { token : Text; amount : Nat };
  public type Self = actor {
    allTokenBalance : shared (Nat, Nat) -> async Result_21;
    batchRefreshIncome : shared query [Nat] -> async Result_20;
    claim : shared ClaimArgs -> async Result_19;
    claimSwapFeeRepurchase : shared (Nat, Principal) -> async Result;
    decreaseLiquidity : shared DecreaseLiquidityArgs -> async Result_19;
    deposit : shared DepositArgs -> async Result;
    depositFrom : shared DepositArgs -> async Result;
    getAccessControlState : shared () -> async {
        owners : [Principal];
        admins : [Principal];
        clients : [Principal];
      };
    getAddressPrincipals : shared query () -> async Result_18;
    getAvailabilityState : shared query () -> async {
        whiteList : [Principal];
        available : Bool;
      };
    getConfigCids : shared query () -> async Result_17;
    getCycleInfo : shared () -> async Result_16;
    getPosition : shared query GetPositionArgs -> async Result_15;
    getPositions : shared query (Nat, Nat) -> async Result_14;
    getPrincipal : shared query Text -> async Result_13;
    getSwapRecordState : shared query () -> async Result_12;
    getTickInfos : shared query (Nat, Nat) -> async Result_11;
    getTicks : shared query (Nat, Nat) -> async Result_10;
    getTokenAmountState : shared query () -> async Result_9; // getTokenAmountState
    getTokenBalance : shared () -> async { token0 : Nat; token1 : Nat };
    getTokenMeta : shared () -> async {
        token0 : [(Text, Value)];
        token1 : [(Text, Value)];
      };
    getUserPosition : shared query Nat -> async Result_8;
    getUserPositionWithTokenAmount : shared query (Nat, Nat) -> async Result_7;
    getUserPositions : shared query (Nat, Nat) -> async Result_6;
    getUserUnusedBalance : shared query Principal -> async Result_5;
    increaseLiquidity : shared IncreaseLiquidityArgs -> async Result;
    init : shared (Nat, Int, Nat) -> async ();
    metadata : shared query () -> async Result_4; // metadata
    mint : shared MintArgs -> async Result;
    quote : shared query SwapArgs -> async Result; // quote
    refreshIncome : shared query Nat -> async Result_3;
    setAvailable : shared Bool -> async ();
    setClients : shared [Principal] -> async ();
    setOwners : shared [Principal] -> async ();
    setSyncInfoAvailable : shared Bool -> async ();
    setTokenStandard : shared Token -> async ();
    setWhiteList : shared [Principal] -> async ();
    snapshotCumulativesInside : shared query SnapshotCumulativesInsideArgs -> async Result_2;
    sumTick : shared query () -> async Result_1;
    swap : shared SwapArgs -> async Result;
    task : shared Text -> async ();
    withdraw : shared WithdrawArgs -> async Result;
  }
}