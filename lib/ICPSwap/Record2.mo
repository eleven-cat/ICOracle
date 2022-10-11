// ctuuq-baaaa-aaaan-qas6q-cai
module {
  public type NatResult = { #ok : Nat; #err : Text };
  public type PublicPoolOverView = {
    id : Nat;
    token0Id : Text;
    token1Id : Text;
    totalVolumeUSD : Float;
    sqrtPrice : Float;
    tvlToken0 : Float;
    tvlToken1 : Float;
    pool : Text;
    tick : Int;
    liquidity : Nat;
    token1Price : Float;
    feeTier : Nat;
    volumeUSD : Float;
    feesUSD : Float;
    feesUSDChange : Float;
    token1Standard : Text;
    tvlUSD : Float;
    volumeUSDWeek : Float;
    txCount : Nat;
    token1Decimals : Float;
    token0Standard : Text;
    token0Symbol : Text;
    volumeUSDChange : Float;
    tvlUSDChange : Float;
    token0Decimals : Float;
    token0Price : Float;
    token1Symbol : Text;
    volumeUSDWeekChange : Float;
  };
  public type PublicSwapChartDayData = {
    id : Int;
    volumeUSD : Float;
    feesUSD : Float;
    tvlUSD : Float;
    timestamp : Int;
    txCount : Int;
  };
  public type TransactionsType = {
    to : Text;
    action : _TransactionType;
    token0Id : Text;
    token1Id : Text;
    liquidityTotal : Nat;
    from : Text;
    exchangePrice : Float;
    hash : Text;
    tick : Int;
    token1Price : Float;
    recipient : Text;
    token0ChangeAmount : Float;
    sender : Text;
    exchangeRate : Float;
    liquidityChange : Nat;
    token1Standard : Text;
    token0Fee : Float;
    token1Fee : Float;
    timestamp : Int;
    token1ChangeAmount : Float;
    token1Decimals : Float;
    token0Standard : Text;
    amountUSD : Float;
    amountToken0 : Float;
    amountToken1 : Float;
    poolFee : Nat;
    token0Symbol : Text;
    token0Decimals : Float;
    token0Price : Float;
    token1Symbol : Text;
    poolId : Text;
  };
  public type _TransactionType = {
    #fee;
    #burn;
    #claim;
    #mint;
    #swap;
    #addLiquidity;
    #removeLiquidity;
    #refreshIncome;
    #transfer;
    #collect;
  };
  public type Self = actor {
    cycleAvailable : shared query () -> async NatResult;
    cycleBalance : shared query () -> async NatResult;
    getAllPools : shared query ?Nat -> async [PublicPoolOverView];
    getBaseDataStructureCanister : shared query () -> async Text;
    getLastID : shared query Nat -> async [(Text, Nat)];
    getPool : shared query Text -> async PublicPoolOverView;
    getPoolChartData : shared query (Text, Nat, Nat) -> async [
        PublicSwapChartDayData
      ];
    getPoolTransactions : shared query (Text, Nat, Nat) -> async [
        TransactionsType
      ];
    getRollIndex : shared query () -> async Nat;
    getStartHeartBeatStatus : shared query () -> async Bool;
    reset : shared () -> async ();
    rollBackData : shared [TransactionsType] -> async ();
    rollBackStatus : shared query Bool -> async ();
    saveTransactions : shared (TransactionsType, Bool) -> async ();
  }
}