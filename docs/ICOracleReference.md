# ICOracle Reference

## Changelist

[Changelist.md](Changelist.md)

## ICOracle Canister

CanisterId: pncff-zqaaa-aaaai-qnp3a-cai

### DID

[../icoracle.did](../icoracle.did)

```
type VolatilityResponse = record {
   average: nat;
   close: nat;
   decimals: nat;
   high: nat;
   low: nat;
   open: nat;
   percent: float64;
};
type Timestamp = nat;
type SourceType = variant {Governance; Dex; Weighted; Conversion; AutoOracle; NodeOracle; HybridOracle;};
type SeriesInfo = record {
   base: text;
   cacheDuration: nat;
   conDuration: nat;
   conMaxDevRate: nat;
   conMinRequired: nat;
   decimals: nat;
   heartbeat: nat;
   name: text;
   quote: text;
   sourceType: SourceType;
   sourceName: text;
   weights: opt vec record{SeriesId; nat};
};
type SeriesId = nat;
type RequestLog = record {
   provider: principal;
   request: DataItem;
   signature: opt blob;
   time: Timestamp;
};
type Provider = principal;
type Log = record {
   confirmed: bool;
   requestLogs: vec RequestLog;
};
type HttpHeader = record {
   name: text;
   value: text;
};
type DataResponse = record {
   data: record { Timestamp; nat; };
   decimals: nat;
   name: text;
   sid: SeriesId;
};
type SeriesDataResponse = record {
   data: vec record { Timestamp; nat; };
   decimals: nat;
   name: text;
   sid: SeriesId;
};
type DataItem = record {
   timestamp: Timestamp;
   value: nat;
};
type CanisterHttpResponsePayload = record {
   body: vec nat8;
   headers: vec HttpHeader;
   status: nat;
};
type OutCallAPI = record {
   host: text;
   key: text;
   name: text;
   url: text;
};
type Category = variant {
   Commodity;
   Crypto;
   Currency;
   Economy;
   Other;
   Social;
   Sports;
   Stock;
   Weather;
};
type ICOracle = service {
   anon_get: (SeriesId, opt Timestamp) -> (opt DataResponse) query;
   anon_getSeries: (SeriesId, opt nat) -> (SeriesDataResponse) query;
   anon_latest: (Category) -> (vec DataResponse) query;
   get: (SeriesId, opt Timestamp) -> (opt DataResponse);
   getSeries: (SeriesId, opt nat) -> (SeriesDataResponse);
   latest: (Category) -> (vec DataResponse);
   volatility: (SeriesId, nat) -> (VolatilityResponse);
   getFee: () -> (nat) query;
   getLog: (SeriesId, opt Timestamp) -> (vec Log) query;
   getSeriesInfo: (SeriesId) -> (opt SeriesInfo) query;
   getWorkload: (Provider) -> (opt record { nat; nat; }) query;
   request: (SeriesId, DataItem, opt blob) -> (bool);
};
service : () -> ICOracle
```

### Motoko Module

[lib/ICOracle.mo](../lib/ICOracle.mo)

## Canister API

Notes.
- The type `Timestamp` means unix timestamps in seconds.
- The type `record { Timestamp; nat; }` means a data item `(datetime, value)` of series data.
- The field `decimals` of series data is the decimal point place of its value, its real value is `value / 10**decimals`.

### anon_get
Returns the latest data item of the series data `SeriesId` before the specified time `Timestamp` (default is current time) by anonymous account query.
```
anon_get: (SeriesId, opt Timestamp) -> (opt DataResponse) query;
```

### anon_getSeries
Returns data items of the series data `SeriesId` by anonymous account query. It supports paging function with 500 data per page.
```
anon_getSeries: (SeriesId, page: opt nat) -> (SeriesDataResponse) query;
```

### anon_latest
Returns the latest data items for all series data by anonymous account query.
```
anon_latest: (Category) -> (vec DataResponse) query;
```

### get
Returns the latest data item of the series data `SeriesId` before the specified time `Timestamp` (default is current time). A fee will be charged for this call.
```
get: (SeriesId, opt Timestamp) -> (opt DataResponse);
```

### getSeries
Returns data items of the series data `SeriesId`. A fee will be charged for this call. It supports paging function with 500 data per page.
```
getSeries: (SeriesId, page: opt nat) -> (SeriesDataResponse);
```

### latest
Returns the latest data items for all series data. A fee will be charged for this call.
```
latest: (Category) -> (vec DataResponse);
```

### volatility
Returns the volatility statistics for the specified time `period` of the series data `SeriesId`. percent = (high - low) / average.
```
volatility: (SeriesId, period: nat) -> (VolatilityResponse);
```

### getFee
Returns base fee, charged in token OT.
```
getFee: () -> (nat) query;
```

### getLog
Returns Oracles' commit records for the series data `SeriesId` for the specified point in time `Timestamp`.
```
getLog: (SeriesId, opt Timestamp) -> (vec Log) query;
```

### getSeriesInfo
Returns the series data information.
```
getSeriesInfo: (SeriesId) -> (opt SeriesInfo) query;
```

### getWorkload
Returns workload statistics for Oracle.
```
getWorkload: (Provider) -> (opt record { nat; nat; }) query;
```

### request
Oracle submits data item, optionally adding a signature.
```
request: (SeriesId, DataItem, opt blob) -> (bool);
```

## HTTP Request

### [Get] https://pncff-zqaaa-aaaai-qnp3a-cai.raw.icp0.io/{BaseToken}/{QuoteToken}
Specify `{BaseToken}` and `{QuoteToken}` in upper case.  
e.g. https://pncff-zqaaa-aaaai-qnp3a-cai.raw.icp0.io/ICP/USD  
returns:
```
{"success": [{"name": "gov:10min:icp/usd", "sid": "2", "base": "ICP", "quote": "USD", "rate": 5.237900, "timestamp": 1667041267 }]}
```

### [Get] https://pncff-zqaaa-aaaai-qnp3a-cai.raw.icp0.io/{sid}
Specify `{sid}` with `sid` of series data.  
e.g. https://pncff-zqaaa-aaaai-qnp3a-cai.raw.icp0.io/2  
returns:
```
{"success": [{"name": "gov:10min:icp/usd", "sid": "2", "base": "ICP", "quote": "USD", "rate": 5.237900, "timestamp": 1667041267 }]}
```

### Error
- 400: Unavailable data
```
{"error": {"code": 400, "message": "Unavailable data"}}
```


## Fee Model 

Token $OT is the utility token of ICOracle and the Dapp pays OT as a fee for an on-chain call (update call), which is currently free of charge. Dapp makes off-chain calls (query call) with an anonymous account (Principal), which is free of charge.

**Base Fee:** 0 OT (Temporarily free, It will be set to 1 OT)

**Cross-canister calling (update call):**

- get: 1 x Base_Fee
- getSeries: 2 x Base_Fee
- latest: 2 x Base_Fee
- volatility: 3 x Base_Fee

**Anonymous off-chain calling (query call):**

- anon_get: free
- anon_getSeries: free
- anon_latest: free

**HTTP Request:**

- Get: free

## Data Feeds

[Data Feeds](DataFeedsList.md)

## Usage 

[Example](../examples/Example.mo)
