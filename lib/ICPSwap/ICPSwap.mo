module {
  public type Address__1 = Text;
  public type Address__2 = Text;
  public type AmountAndCycleResult = {
    cycles : Nat;
    amount0 : Nat;
    amount1 : Nat;
  };
  public type InitParameters = {
    fee : Nat;
    tickSpacing : Nat;
    token1Standard : Text;
    token0 : Address__1;
    token1 : Address__1;
    factory : Address__1;
    token0Standard : Text;
    canisterId : Text;
  };
  public type Int24 = Int;
  public type Int256 = Int;
  public type NatResult__1 = { #ok : Nat; #err : Text };
  public type PaymentEntry = {
    token : Address__1;
    value : Nat;
    tokenStandard : Text;
    recipient : Principal;
    payer : Principal;
  };
  public type PoolInfo = {
    fee : Nat;
    ticks : [Int];
    pool : Text;
    liquidity : Nat;
    tickCurrent : Int;
    token0 : Text;
    token1 : Text;
    sqrtRatioX96 : Nat;
    balance0 : Nat;
    balance1 : Nat;
  };
  public type PositionInfo = {
    tokensOwed0 : Nat;
    tokensOwed1 : Nat;
    feeGrowthInside1LastX128 : Nat;
    liquidity : Nat;
    feeGrowthInside0LastX128 : Nat;
  };
  public type ResponseResult_1 = { #ok : SwapResult; #err : Text };
  public type ResponseResult_2 = {
    #ok : { cycles : Nat; amount0 : Int; amount1 : Int };
    #err : Text;
  };
  public type ResponseResult_3 = { #ok : AmountAndCycleResult; #err : Text };
  public type ResponseResult_4 = { #ok : [Text]; #err : Text };
  public type SharedSlot0 = {
    observationCardinalityNext : Nat;
    sqrtPriceX96 : Nat;
    observationIndex : Nat;
    feeProtocol : Nat;
    tick : Int;
    unlocked : Bool;
    observationCardinality : Nat;
  };
  public type SnapshotCumulativesInsideResult = {
    tickCumulativeInside : Int;
    secondsPerLiquidityInsideX128 : Nat;
    secondsInside : Nat;
  };
  public type SwapResult = {
    feeAmount : Int;
    cycles : Nat;
    amount0 : Int;
    amount1 : Int;
  };
  public type TextResult = { #ok : Text; #err : Text };
  public type TickLiquidityInfo = {
    tickIndex : Int;
    price0Decimal : Nat;
    liquidityNet : Int;
    price0 : Nat;
    price1 : Nat;
    liquidityGross : Nat;
    price1Decimal : Nat;
  };
  public type Uint128 = Nat;
  public type Uint16 = Nat;
  public type Uint160 = Nat;
  public type VolumeMapType = { tokenA : Nat; tokenB : Nat };
  public type Self = actor {
    balance : shared Text -> async NatResult__1;
    balance0 : shared () -> async NatResult__1;
    balance1 : shared () -> async NatResult__1;
    burn : shared (Int, Int, Nat) -> async ResponseResult_3;
    claimSwapFeeRepurchase : shared () -> async ();
    collect : shared (Principal, Int, Int, Nat, Nat) -> async ResponseResult_3;
    cycleAvailable : shared () -> async Nat;
    cycleBalance : shared query () -> async Nat;
    get24HVolume : shared query () -> async VolumeMapType;
    getAdminList : shared query () -> async ResponseResult_4;
    getPosition : shared query Text -> async PositionInfo;
    getSlot0 : shared query () -> async SharedSlot0;
    getStandard : shared query Text -> async Text;
    getSwapFeeRepurchase : shared query () -> async {
        amount0 : Nat;
        amount1 : Nat;
      };
    getSwapTokenMap : shared query Text -> async Int;
    getTickInfos : shared query () -> async [TickLiquidityInfo];
    getTickSpacing : shared query () -> async Int;
    getTotalVolume : shared query () -> async VolumeMapType;
    getWalletAddress : shared () -> async Address__2;
    increaseObservationCardinalityNext : shared Uint16 -> async TextResult;
    info : shared () -> async PoolInfo;
    infoWithNoBalance : shared query () -> async PoolInfo;
    init : shared InitParameters -> async ();
    initAdminList : shared [Text] -> async ();
    initialize : shared Uint160 -> async ();
    lockPool : shared () -> async ();
    mint : shared (
        Principal,
        Int24,
        Int24,
        Uint128,
        Nat,
        Nat,
      ) -> async ResponseResult_3;
    quoter : shared query (Int, Nat, Bool, Nat, Nat) -> async ResponseResult_2;
    rollBackData : shared () -> async ();
    rollBackTransfer : shared () -> async [PaymentEntry];
    setAvailable : shared Bool -> ();
    setFeeProtocol : shared (Nat, Nat) -> async TextResult;
    setLockServerCanisterId : shared Text -> async ();
    setSwapFeeHolderCanisterId : shared Principal -> async ();
    setSwapFeeRepurchase : shared (Nat, Nat) -> async ();
    setTransFeeCache : shared () -> async ();
    snapshotCumulativesInside : shared query (
        Int24,
        Int24,
      ) -> async SnapshotCumulativesInsideResult;
    swap : shared (
        Principal,
        Int256,
        Uint160,
        Bool,
        Nat,
        Nat,
      ) -> async ResponseResult_1;
    transFee : shared Text -> async NatResult__1;
    transFee0 : shared () -> async NatResult__1;
    transFee0Cache : shared query () -> async NatResult__1;
    transFee1 : shared () -> async NatResult__1;
    transFee1Cache : shared query () -> async NatResult__1;
    transFeeCache : shared query Text -> async NatResult__1;
    unlockPool : shared () -> async ();
  }
}