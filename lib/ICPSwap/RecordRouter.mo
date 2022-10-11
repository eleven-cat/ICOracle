// jrg47-niaaa-aaaan-qatda-cai
module {
  public type Address = Text;
  public type Address__1 = Text;
  public type BoolResult = { #ok : Bool; #err : Text };
  public type NatResult = { #ok : Nat; #err : Text };
  public type PushError = { time : Int; message : Text };
  public type ResponseResult = { #ok : [Text]; #err : Text };
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
  public type TxStorageCanisterResponse = {
    errors : [PushError];
    retryCount : Nat;
    canisterId : Text;
  };
  public type Self = actor {
    addAdmin : shared Text -> async BoolResult;
    clearTxStorageErrors : shared () -> async Nat;
    cycleAvailable : shared () -> async NatResult;
    cycleBalance : shared query () -> async NatResult;
    exactInput : shared (
        Address__1,
        Principal,
        Nat,
        Text,
        Text,
      ) -> async NatResult;
    exactInputSingle : shared (
        Address__1,
        Principal,
        Nat,
        Text,
        Text,
        Text,
      ) -> async NatResult;
    exactOutput : shared (
        Address__1,
        Principal,
        Nat,
        Text,
        Text,
      ) -> async NatResult;
    exactOutputSingle : shared (
        Address__1,
        Principal,
        Nat,
        Text,
        Text,
        Text,
      ) -> async NatResult;
    getAdminList : shared query () -> async ResponseResult;
    getCachedSwapRecord : shared query () -> async [SwapRecordInfo];
    getIntervalTime : shared query () -> async Int;
    getMaxRetrys : shared query () -> async Nat;
    getTxStorage : shared query () -> async ?TxStorageCanisterResponse;
    getUnitPrice : shared (Text, Text) -> async NatResult;
    isTxStorageAvailable : shared query () -> async Bool;
    quoteExactInput : shared (Text, Text) -> async NatResult;
    quoteExactInputSingle : shared (Text, Text, Text) -> async NatResult;
    quoteExactOutput : shared (Text, Text) -> async NatResult;
    recoverTxStorage : shared () -> async Nat;
    removeAdmin : shared Text -> async BoolResult;
    removeTxStorage : shared () -> async ();
    setAvailable : shared Bool -> ();
    setBaseDataStructureCanister : shared Text -> async ();
    setIntervalTime : shared Int -> async ();
    setMaxRetrys : shared Nat -> async ();
    setTxStorage : shared ?Text -> async Nat;
  }
}