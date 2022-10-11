// cuvse-myaaa-aaaan-qas6a-cai
module {
  public type NatResult = { #ok : Nat; #err : Text };
  public type PoolInfo = {
    fee : Int;
    token0Id : Text;
    token1Id : Text;
    pool : Text;
    token1Price : Float;
    token1Decimals : Float;
    token0Symbol : Text;
    token0Decimals : Float;
    token0Price : Float;
    token1Symbol : Text;
  };
  public type PublicTokenChartDayData = {
    id : Int;
    volumeUSD : Float;
    tvlUSD : Float;
    timestamp : Int;
    txCount : Int;
  };
  public type PublicTokenOverview = {
    id : Nat;
    totalVolumeUSD : Float;
    name : Text;
    priceUSDChangeWeek : Float;
    volumeUSD : Float;
    feesUSD : Float;
    priceUSDChange : Float;
    tvlUSD : Float;
    address : Text;
    volumeUSDWeek : Float;
    txCount : Int;
    priceUSD : Float;
    volumeUSDChange : Float;
    tvlUSDChange : Float;
    standard : Text;
    tvlToken : Float;
    symbol : Text;
  };
  public type PublicTokenPricesData = {
    id : Int;
    low : Float;
    high : Float;
    close : Float;
    open : Float;
    timestamp : Int;
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
    getAllToken : shared query ?Nat -> async [PublicTokenOverview];
    getBaseDataStructureCanister : shared query () -> async Text;
    getLastID : shared query Nat -> async [(Text, Nat)];
    getPoolsForToken : shared query Text -> async [PoolInfo];
    getRollIndex : shared query () -> async Nat;
    getStartHeartBeatStatus : shared query () -> async Bool;
    getToken : shared query Text -> async PublicTokenOverview;
    getTokenChartData : shared query (Text, Nat, Nat) -> async [
        PublicTokenChartDayData
      ];
    getTokenPricesData : shared query (Text, Int, Int, Nat) -> async [
        PublicTokenPricesData
      ];
    getTokenTransactions : shared query (Text, Nat, Nat) -> async [
        TransactionsType
      ];
    getTvlRecord : shared query Nat -> async [(Text, [Float])];
    reset : shared () -> async ();
    rollBackData : shared [TransactionsType] -> async ();
    rollBackStatus : shared query Bool -> async ();
    saveTransactions : shared (TransactionsType, Bool) -> async ();
  }
}