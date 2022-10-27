# ICOracle Reference

## Changelist

### v0.3 Alpha

- Fix Bugs
- Fetching data using https outcall
- Refactoring SeriesInfo data type
- Refactoring latest() and anon_latest() functions
- Support for http_request query data
- Support for 24 Currencies(XDR/USD,EUR/USD,GBP/USD,JPY/USD,AUD/USD,CHF/USD,NZD/USD,CAD/USD,HKD/USD,SGD/USD,CNY/USD,KRW/USD,TRY/USD,INR/USD,RUB/USD,MXN/USD,ZAR/USD,SEK/USD,DKK/USD,THB/USD,VND/USD,MYR/USD,TWD/USD,BRL/USD) rate data

### v0.2 Alpha

- Initial version
- Support for ICP/USD Data Feeds

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
   anon_get: (SeriesId, opt Timestamp) -> (opt record { data: record { Timestamp; nat; }; decimals: nat; }) query;
   anon_getSeries: (SeriesId, opt nat) -> (record { data: vec record { Timestamp; nat; }; decimals: nat; }) query;
   anon_latest: (Category) -> (vec record { data: record { Timestamp; nat; }; decimals: nat; name: text;sid: SeriesId;}) query;
   get: (SeriesId, opt Timestamp) -> (opt record { data: record { Timestamp; nat;}; decimals: nat;});
   getSeries: (SeriesId, opt nat) -> (record { data: vec record { Timestamp; nat; }; decimals: nat;});
   latest: (Category) -> (vec DataResponse);
   volatility: (SeriesId, nat) -> (VolatilityResponse);
   getFee: () -> (nat) query;
   getLog: (SeriesId, opt Timestamp) -> (opt Log) query;
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
anon_get: (SeriesId, opt Timestamp) -> (opt record { data: record { Timestamp; nat; }; decimals: nat; }) query;
```

### anon_getSeries
Returns data items of the series data `SeriesId` by anonymous account query. It supports paging function with 500 data per page.
```
anon_getSeries: (SeriesId, page: opt nat) -> (record { data: vec record { Timestamp; nat; }; decimals: nat; }) query;
```

### anon_latest
Returns the latest data items for all series data by anonymous account query.
```
anon_latest: (Category) -> (vec record { data: record { Timestamp; nat; }; decimals: nat; name: text;sid: SeriesId;}) query;
```

### get
Returns the latest data item of the series data `SeriesId` before the specified time `Timestamp` (default is current time). A fee will be charged for this call.
```
get: (SeriesId, opt Timestamp) -> (opt record { data: record { Timestamp; nat; }; decimals: nat; }) query;
```

### getSeries
Returns data items of the series data `SeriesId`. A fee will be charged for this call. It supports paging function with 500 data per page.
```
getSeries: (SeriesId, page: opt nat) -> (record { data: vec record { Timestamp; nat; }; decimals: nat; }) query;
```

### latest
Returns the latest data items for all series data. A fee will be charged for this call.
```
latest: (Category) -> (vec record { data: record { Timestamp; nat; }; decimals: nat; name: text;sid: SeriesId;}) query;
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
getLog: (SeriesId, opt Timestamp) -> (opt Log) query;
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

### https://pncff-zqaaa-aaaai-qnp3a-cai.raw.ic0.app/{BaseToken}/{QuoteToken}
Enter `{BaseToken}` and `{QuoteToken}` in upper case.  
e.g. https://pncff-zqaaa-aaaai-qnp3a-cai.raw.ic0.app/ICP/USD  
returns:
```
{"success": {"base": "ICP", "quote": "USD", "rate": 5.306500, "timestamp": 1666852332 }}
```

### https://pncff-zqaaa-aaaai-qnp3a-cai.raw.ic0.app/{sid}
Enter `{sid}` with `sid` of series data.  
e.g. https://pncff-zqaaa-aaaai-qnp3a-cai.raw.ic0.app/2  
returns:
```
{"success": {"base": "ICP", "quote": "USD", "rate": 5.306500, "timestamp": 1666852332 }}
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

## Data Feeds

[Data Feeds](DataFeedsList.md)

## Usage 

[Example](../examples/Example.mo)
