module {
    public type Provider = Principal;
    public type SeriesId = Nat;
    public type HeartbeatId = Nat; // interval: [start, end)
    public type Timestamp = Nat; // seconds
    // public type SeriesInfo = { // time series data info
    //     name: Text;
    //     decimals: Nat; // per 10^decimals
    //     heartbeat: Nat; // seconds
    //     conMaxDevRate: Nat; // ‱ permyriad
    //     conMinRequired: Nat; // Each aggregation requires at least 'conMinRequired' oracles calculate a trusted value.
    //     conDuration: Nat; // seconds
    //     cacheDuration: Nat; // seconds
    // };
    public type SourceType = {#Governance; #Dex; #Weighted; #Conversion; #AutoOracle; #NodeOracle; #HybridOracle;}; // AutoOracle = Https outcall
    public type SeriesInfo = { // time series data info
        name: Text;
        base: Text; // e.g. ICP
        quote: Text; // e.g. USD
        decimals: Nat; // per 10^decimals
        heartbeat: Nat; // seconds
        conMaxDevRate: Nat; // ‱ permyriad
        conMinRequired: Nat; // Each aggregation requires at least 'conMinRequired' oracles calculate a trusted value.
        conDuration: Nat; // seconds
        cacheDuration: Nat; // seconds
        sourceType: SourceType;
        sourceName: Text;
        weights: ?[(SeriesId, weight: Nat)]; // total weight: 100
    };
    public type DexPair = (dex: Text, pair: Principal, reciprocal: Bool, token0Decimals: Nat, token1Decimals: Nat);
    public type DataItem = { value: Nat; timestamp: Timestamp;};
    public type DataResponse = {name: Text; sid: SeriesId; decimals: Nat; data:(ts: Timestamp, value: Nat)};
    public type SeriesDataResponse = {name: Text; sid: SeriesId; decimals: Nat; data:[(ts: Timestamp, value: Nat)]};
    public type VolatilityResponse = {open: Nat; high: Nat; low: Nat; close: Nat; average: Nat; percent: Float; decimals: Nat};
    public type RequestLog = {
        request: DataItem;
        provider: Principal;
        time: Timestamp;
        signature: ?Blob;
    };
    public type Log = {
        confirmed: Bool;
        requestLogs: [RequestLog]; 
    };
    public type OutCallAPI = {
        name: Text;
        host: Text;
        url: Text;
        key: Text;
    };
    public type Category = {
        #Crypto; 
        #Currency; 
        #Commodity; 
        #Stock; 
        #Economy; 
        #Weather;
        #Sports;
        #Social;
        #Other;
    };

    public type Self = actor {
        // paying $OT for cross-canister calling (update call)
        // sid(xdr/usd):0   sid(icp/xdr):1   sid(icp/usd):2
        get : shared (_sid: SeriesId, _tsSeconds: ?Timestamp) -> async ?DataResponse; // 1 x fee
        getSeries : shared (_sid: SeriesId, _page: ?Nat) -> async SeriesDataResponse; // 2 x fee
        latest : shared (_cat: Category) -> async [DataResponse]; // 2 x fee
        volatility : shared (_sid: SeriesId, _period: Nat) -> async VolatilityResponse; // 3 x fee
        // free for anonymous off-chain calling (query call)
        anon_get : shared query (_sid: SeriesId, _tsSeconds: ?Timestamp) -> async ?DataResponse; 
        anon_getSeries : shared query (_sid: SeriesId, _page: ?Nat) -> async SeriesDataResponse; 
        anon_latest : shared query (_cat: Category) -> async [DataResponse]; 
        // oracle / node
        request : shared (_sid: SeriesId, _data: DataItem, signature: ?Blob) -> async (confirmed: Bool);
        // query
        getFee : shared query () -> async Nat;
        getSeriesInfo : shared query (_sid: SeriesId) -> async ?SeriesInfo;
        getLog : shared query (_sid: SeriesId, _tsSeconds: ?Timestamp) -> async [Log]; //**//
        getWorkload : shared query (_account: Provider) -> async ?(score: Nat, invalid: Nat);
    };
    
};