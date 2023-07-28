
module{
    public type Reserves = {
        reserve0: Nat;
        reserve1: Nat;
        block_timestamp_last: Nat32;
    };
    public type CumulativePrice = {
        price0: Nat;
        price1: Nat;
        timestamp: Nat32;
    };
    public type Self = actor {
        get_token0 : shared query () -> async Principal;
        get_token1 : shared query () -> async Principal;
        get_current_price : shared query () -> async (Float, Float); // token1 / token0      token0 / token1
        get_reserves : shared query () -> async Reserves;
        get_cumulative_price : shared query () -> async CumulativePrice;
    };
};