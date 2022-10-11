// cbsdj-nqaaa-aaaan-qas5q-cai
module {
  public type Address = Text;
  public type Address__1 = Text;
  public type NatResult = { #ok : Nat; #err : Text };
  public type Page = {
    content : [TransactionsType];
    offset : Nat;
    limit : Nat;
    totalElements : Nat;
  };
  public type PublicProtocolData = {
    volumeUSD : Float;
    feesUSD : Float;
    feesUSDChange : Float;
    tvlUSD : Float;
    txCount : Int;
    volumeUSDChange : Float;
    tvlUSDChange : Float;
  };
  public type PublicSwapChartDayData = {
    id : Int;
    volumeUSD : Float;
    feesUSD : Float;
    tvlUSD : Float;
    timestamp : Int;
    txCount : Int;
  };
  public type RecordPage = {
    content : [TransactionsType];
    offset : Nat;
    limit : Nat;
    totalElements : Nat;
  };
  public type SwapRecordInfo = {
    to : Text;
    feeAmount : Int;
    action : TransactionType;
    feeAmountTotal : Int;
    token0Id : Address;
    token1Id : Address;
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
  public type TransactionType = {
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
    addAdmin : shared Text -> async Bool;
    backBaseData : shared () -> async ();
    clearCacheRecordBack : shared () -> async ();
    cycleAvailable : shared query () -> async NatResult;
    cycleBalance : shared query () -> async NatResult;
    get : shared query (Address__1, Nat, Nat) -> async RecordPage;
    getAddressAndCountByCondition : shared query (
        Text,
        Text,
        Nat,
        Nat,
        Nat,
      ) -> async [{ count : Nat; address : Text }];
    getAdminList : shared () -> async [Text];
    getAllTransactions : shared query (
        Text,
        Text,
        Int,
        ?TransactionType,
        Nat,
        Nat,
      ) -> async Page;
    getBaseRecord : shared query (Nat, Nat) -> async RecordPage;
    getCanister : shared () -> async [Text];
    getChartData : shared query (Nat, Nat) -> async [PublicSwapChartDayData];
    getPoolLastPrice : shared query Text -> async Float;
    getPoolLastRate : shared query Text -> async Float;
    getProtocolData : shared query () -> async PublicProtocolData;
    getSwapPositionManagerCanisterId : shared query () -> async Text;
    getSwapUserAddress : shared query () -> async [Text];
    getSwapUserNum : shared query () -> async Nat;
    getTotalValueLockedUSD : shared query () -> async Nat;
    getTxCount : shared query () -> async Nat;
    isAdmin : shared Text -> async Bool;
    push : shared SwapRecordInfo -> async ();
    removeAdmin : shared Text -> async Bool;
    removePoolList : shared Text -> async ();
    removeTokenList : shared Text -> async ();
    rollBackBaseData : shared () -> async ();
    rollBackCache : shared () -> async ();
    rollBackDataBaseRecord : shared (Nat, Nat) -> async ();
    rollBackData_Pools : shared (Nat, Nat) -> async ();
    rollBackData_Token : shared (Nat, Nat) -> async ();
    rollBackStatus : shared Bool -> async ();
    rollBackSwapDayData : shared () -> async ();
    rollBackUserRecord : shared () -> async ();
    setCanister : shared (Text, Text) -> async ();
    setSwapPositionManagerCanisterId : shared Text -> async ();
    sortBaseData : shared () -> async ();
  }
}