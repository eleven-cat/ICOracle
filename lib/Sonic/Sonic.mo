// Router: 3xwpq-ziaaa-aaaah-qcn4a-cai
module {
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
  public type TokenInfoExt = {
    id : Text;
    fee : Nat;
    decimals : Nat8;
    name : Text;
    totalSupply : Nat;
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
    addLiquidity : shared (token0: Principal, token1: Principal, amount0Desired: Nat, amount1Desired: Nat, amount0Min: Nat, amount1Min: Nat, deadline: Int) -> async TxReceipt;
    addToken : shared Principal -> async TxReceipt;
    allowance : shared query (Text, Principal, Principal) -> async Nat;
    approve : shared (Text, Principal, Nat) -> async Bool;
    balanceOf : shared query (Text, Principal) -> async Nat;
    createPair : shared (token0: Principal, token1: Principal) -> async TxReceipt;
    decimals : shared query Text -> async Nat8;
    deposit : shared (tokenId: Principal, value: Nat) -> async TxReceipt;
    depositTo : shared (Principal, Principal, Nat) -> async TxReceipt;
    exportBalances : shared query Text -> async ?[(Principal, Nat)];
    exportLPTokens : shared query () -> async [TokenInfoExt];
    exportPairs : shared query () -> async [PairInfoExt];
    exportTokens : shared query () -> async [TokenInfoExt];
    getAllPairs : shared query () -> async [PairInfoExt];
    getHolders : shared query Text -> async Nat;
    getLPTokenId : shared query (Principal, Principal) -> async Text;
    getNumPairs : shared query () -> async Nat;
    getPair : shared query (token0: Principal, token1: Principal) -> async ?PairInfoExt;
    getPairs : shared query (Nat, Nat) -> async ([PairInfoExt], Nat);
    getSupportedTokenList : shared query () -> async [TokenInfoExt];
    getSupportedTokenListByName : shared query (Text, Nat, Nat) -> async (
        [TokenInfoExt],
        Nat,
      );
    getSupportedTokenListSome : shared query (Nat, Nat) -> async (
        [TokenInfoExt],
        Nat,
      );
    getSwapInfo : shared query () -> async SwapInfo;
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
    name : shared query Text -> async Text;
    removeAuth : shared Principal -> async Bool;
    removeLiquidity : shared (token0: Principal, token1: Principal, lpAmount: Nat, amount0Min: Nat, amount1Mint: Nat, deadline: Int) -> async TxReceipt;
    setFeeForToken : shared (Text, Nat) -> async Bool;
    setFeeOn : shared Bool -> async Bool;
    setFeeTo : shared Principal -> async Bool;
    setGlobalTokenFee : shared Nat -> async Bool;
    setMaxTokens : shared Nat -> async Bool;
    setOwner : shared Principal -> async Bool;
    setPermissionless : shared Bool -> async Bool;
    swapExactTokensForTokens : shared (amountIn: Nat, amountOutMin: Nat, path: [Text], to: Principal, deadline: Int) -> async TxReceipt;
    swapTokensForExactTokens : shared (amountOut: Nat, amountInMax: Nat, path: [Text], to: Principal, deadline: Int) -> async TxReceipt;
    symbol : shared query Text -> async Text;
    totalSupply : shared query Text -> async Nat;
    transfer : shared (tokenId: Text, to: Principal, value: Nat) -> async Bool;
    transferFrom : shared (Text, Principal, Principal, Nat) -> async Bool;
    updateAllTokenMetadata : shared () -> async Bool;
    updateTokenFees : shared () -> async Bool;
    updateTokenMetadata : shared Text -> async Bool;
    withdraw : shared (tokenId: Principal, value: Nat) -> async TxReceipt;
    withdrawTo : shared (Principal, Principal, Nat) -> async TxReceipt;
  }
}