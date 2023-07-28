// Router: 3xwpq-ziaaa-aaaah-qcn4a-cai

module {
  public type DepositSubAccounts = {
    depositAId : Text;
    subaccount : Blob;
    created_at : Time;
    transactionOwner : Principal;
  };
  public type ICRCTxReceipt = { #Ok : Blob; #Err : Text };
  public type PairInfoExt = {
    id : Text;
    price0CumulativeLast : Nat;
    creator : Principal;
    reserve0 : Nat;
    reserve1 : Nat;
    lptoken : Text;
    totalSupply : Nat;
    token0 : Text;
    token1 : Text;
    price1CumulativeLast : Nat;
    kLast : Nat;
    blockTimestampLast : Int;
  };
  public type SwapInfo = {
    owner : Principal;
    cycles : Nat;
    tokens : [TokenInfoExt];
    pairs : [PairInfoExt];
  };
  public type Time = Int;
  public type TokenAnalyticsInfo = {
    fee : Nat;
    decimals : Nat8;
    name : Text;
    totalSupply : Nat;
    symbol : Text;
  };
  public type TokenInfoExt = {
    id : Text;
    fee : Nat;
    decimals : Nat8;
    name : Text;
    totalSupply : Nat;
    symbol : Text;
  };
  public type TokenInfoWithType = {
    id : Text;
    fee : Nat;
    decimals : Nat8;
    name : Text;
    totalSupply : Nat;
    tokenType : Text;
    symbol : Text;
  };
  public type TxReceipt = { #ok : Nat; #err : Text };
  public type UserInfo = {
    lpBalances : [(Text, Nat)];
    balances : [(Text, Nat)];
  };
  public type UserInfoPage = {
    lpBalances : ([(Text, Nat)], Nat);
    balances : ([(Text, Nat)], Nat);
  };
  public type Self = actor {
    addAuth : shared Principal -> async Bool;
    addLiquidity : shared (
        Principal,
        Principal,
        Nat,
        Nat,
        Nat,
        Nat,
        Int,
      ) -> async TxReceipt;
    addLiquidityForUser : shared (
        Principal,
        Principal,
        Principal,
        Nat,
        Nat,
      ) -> async TxReceipt;
    addLiquidityForUserTest : shared (
        Principal,
        Principal,
        Principal,
        Nat,
        Nat,
      ) -> async Text;
    addToken : shared (Principal, Text) -> async TxReceipt;
    allowance : shared query (Text, Principal, Principal) -> async Nat;
    approve : shared (Text, Principal, Nat) -> async Bool;
    balanceOf : shared query (Text, Principal) -> async Nat;
    burn : shared (Text, Nat) -> async Bool;
    createPair : shared (Principal, Principal) -> async TxReceipt;
    decimals : shared query Text -> async Nat8;
    deposit : shared (Principal, Nat) -> async TxReceipt;
    depositTo : shared (Principal, Principal, Nat) -> async TxReceipt;
    exportBalances : shared query Text -> async ?[(Principal, Nat)];
    exportLPTokens : shared query () -> async [TokenInfoExt];
    exportPairs : shared query () -> async [PairInfoExt];
    exportSubAccounts : shared () -> async [(Principal, DepositSubAccounts)];
    exportTokenTypes : shared query () -> async [(Text, Text)];
    exportTokens : shared query () -> async [TokenInfoExt];
    getAllPairs : shared query () -> async [PairInfoExt];
    getBalance : shared (Principal, Text) -> async Nat;
    getHolders : shared query Text -> async Nat;
    getLPTokenId : shared query (Principal, Principal) -> async Text;
    getNumPairs : shared query () -> async Nat;
    getPair : shared query (Principal, Principal) -> async ?PairInfoExt; // getPair
    getPairs : shared query (Nat, Nat) -> async ([PairInfoExt], Nat);
    getSupportedTokenList : shared query () -> async [TokenInfoWithType];
    getSupportedTokenListByName : shared query (Text, Nat, Nat) -> async (
        [TokenInfoExt],
        Nat,
      );
    getSupportedTokenListSome : shared query (Nat, Nat) -> async (
        [TokenInfoExt],
        Nat,
      );
    getSwapInfo : shared query () -> async SwapInfo;
    getTokenMetadata : shared query Text -> async TokenAnalyticsInfo;
    getUserBalances : shared query Principal -> async [(Text, Nat)];
    getUserInfo : shared query Principal -> async UserInfo;
    getUserInfoAbove : shared query (Principal, Nat, Nat) -> async UserInfo;
    getUserInfoByNamePageAbove : shared query (
        Principal,
        Int,
        Text,
        Nat,
        Nat,
        Int,
        Text,
        Nat,
        Nat,
      ) -> async UserInfoPage;
    getUserLPBalances : shared query Principal -> async [(Text, Nat)];
    getUserLPBalancesAbove : shared query (Principal, Nat) -> async [
        (Text, Nat)
      ];
    historySize : shared () -> async Nat;
    initateTransfer : shared () -> async Text;
    initiateICRC1Transfer : shared () -> async Blob;
    initiateICRC1TransferForUser : shared Principal -> async ICRCTxReceipt;
    name : shared query Text -> async Text;
    removeAuth : shared Principal -> async Bool;
    removeLiquidity : shared (
        Principal,
        Principal,
        Nat,
        Nat,
        Nat,
        Principal,
        Int,
      ) -> async TxReceipt;
    retryDepositTo : shared (Principal, Principal, Nat) -> async TxReceipt;
    setDaoCanisterForLiquidity : shared Principal -> async Text;
    setFeeForToken : shared (Text, Nat) -> async Bool;
    setFeeOn : shared Bool -> async Bool;
    setFeeTo : shared Principal -> async Bool;
    setGlobalTokenFee : shared Nat -> async Bool;
    setMaxTokens : shared Nat -> async Bool;
    setOwner : shared Principal -> async Bool;
    setPairSupply : shared (Text, Nat) -> async Bool;
    setPermissionless : shared Bool -> async Bool;
    swapExactTokensForTokens : shared (
        Nat,
        Nat,
        [Text],
        Principal,
        Int,
      ) -> async TxReceipt;
    swapTokensForExactTokens : shared (
        Nat,
        Nat,
        [Text],
        Principal,
        Int,
      ) -> async TxReceipt;
    symbol : shared query Text -> async Text;
    totalSupply : shared query Text -> async Nat;
    transfer : shared (Text, Principal, Nat) -> async Bool;
    transferFrom : shared (Text, Principal, Principal, Nat) -> async Bool;
    updateAllTokenMetadata : shared () -> async Bool;
    updateTokenFees : shared () -> async Bool;
    updateTokenMetadata : shared Text -> async Bool;
    withdraw : shared (Principal, Nat) -> async TxReceipt;
    withdrawTo : shared (Principal, Principal, Nat) -> async TxReceipt;
  }
}