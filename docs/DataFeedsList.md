# Data Feeds

- **xdr/usd** (sid: 0)  
    heartbeat: 1h, decimals: 4, data sources: xe.com (off-chain)
- **icp/xdr** (sid: 1)  
    heartbeat: 10min, decimals: 4, data sources: Dfinity Foundation (on-chain)
- **icp/usd** (sid: 2)  
    heartbeat: 10min, decimals: 4, data sources: ICOracle (on-chain calculation)  
    Notes: The icp/usd conversion rate is calculated based on xdr/usd (sid=0) and icp/xdr (sid=1).