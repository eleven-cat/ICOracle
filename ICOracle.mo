/**
 * Module     : ICOracle.mo
 * Author     : ICOracle Team
 * Stability  : Experimental
 * Description: Decentralized oracle network on IC blockchain.
 * Refers     : https://github.com/eleven-cat/ICOracle
 */

import Prelude "mo:base/Prelude";
import Array "mo:base/Array";
import ArrayTool "./lib/ArrayTool";
import Blob "mo:base/Blob";
import Hash "mo:base/Hash";
import Int "mo:base/Int";
import Int64 "mo:base/Int64";
import Iter "mo:base/Iter";
import List "mo:base/List";
import Char "mo:base/Char";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Float "mo:base/Float";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Cycles "mo:base/ExperimentalCycles";
import Text "mo:base/Text";
import T "./lib/ICOracle";
import Time "mo:base/Time";
import Debug "mo:base/Debug";
import Error "mo:base/Error";
import Trie "mo:base/Trie";
import Tools "./lib/ICLighthouse/Tools";
import Minting "./lib/CyclesMinting";
import ICHTTP "./lib/ICHTTP";
import DRC207 "./lib/ICLighthouse/DRC207";
import IC "./lib/IC";
import DexRouter "./lib/ICLighthouse/DexRouter";
import ICSwap "./lib/ICLighthouse/ICSwap";
import ICDex "./lib/ICLighthouse/ICDexTypes";
import Sonic "./lib/Sonic/Sonic";
import ICPSwap "./lib/ICPSwap/ICPSwap";
import Timer "mo:base/Timer"
// import CertifiedData "mo:base/CertifiedData";

shared(installMsg) actor class ICOracle() = this {
    type Provider = T.Provider;
    type SeriesId = T.SeriesId;
    type HeartbeatId = T.HeartbeatId; // interval: [start, end)
    type Timestamp = T.Timestamp; // seconds
    type SeriesInfo = T.SeriesInfo;
    type DexPair = T.DexPair;
    type DataItem = T.DataItem;
    type RequestLog = T.RequestLog;
    type Log = T.Log;
    type DataResponse = T.DataResponse;
    type SeriesDataResponse = T.SeriesDataResponse;
    type VolatilityResponse = T.VolatilityResponse;

    // Variables
    private let version_: Text = "0.5";
    private let name_: Text = "ICOracle";
    private let tokenCanister = "imeri-bqaaa-aaaai-qnpla-cai"; // $OT
    private let dexRouter = "j4d4d-pqaaa-aaaak-aanxq-cai";
    private let icdexRouter = "ltyfs-qiaaa-aaaak-aan3a-cai";
    private let sonicRouter = "3xwpq-ziaaa-aaaah-qcn4a-cai";
    private let MAX_RESPONSE_BYTES = 100 * 1024; // 100K
    private stable var setting_apilayer: T.OutCallAPI = { name="";host="";url="";key=""; };
    private stable var setting_binance: T.OutCallAPI = { name="";host="";url="";key=""; };
    private stable var setting_coinmarketcap: T.OutCallAPI = { name="";host="";url="";key=""; };
    private stable var setting_coinbase: T.OutCallAPI = { name="";host="";url="";key=""; };
    private stable var fee: Nat = 0; //  100000000 OT 
    private stable var owner: Principal = installMsg.caller;
    private stable var providers = List.nil<(Provider, [SeriesId], [Principal])>();
    private stable var workloads: Trie.Trie<Provider, (score: Nat, invalid: Nat)> = Trie.empty();
    private stable var index: Nat = 3;
    private stable var seriesInfo: Trie.Trie<SeriesId, (SeriesInfo, Timestamp)> = Trie.empty();
    private stable var seriesData: Trie.Trie2D<SeriesId, HeartbeatId, DataItem> = Trie.empty(); //##//
    private stable var seriesData2: Trie.Trie2D<SeriesId, HeartbeatId, [DataItem]> = Trie.empty(); // latest data is in position 0.
    private stable var requestLogs: Trie.Trie2D<SeriesId, HeartbeatId, Log> = Trie.empty(); //##//
    private stable var requestLogs2: Trie.Trie2D<SeriesId, HeartbeatId, [Log]> = Trie.empty();
    private stable var dexPairs: Trie.Trie<SeriesId, DexPair> = Trie.empty(); //  dex: "icdex"

    // query from trie
    private func triePage<V>(_trie: Trie.Trie<Nat,V>, _start: Nat, _page: Nat, _period: Nat) : [(Nat, V)] {
        if (_page < 1){
            return [];
        };
        let offset = Nat.sub(_page, 1) * _period;
        var start: Nat = _start;
        if (_start > offset){
            start := Nat.sub(_start, offset);
        };
        var end: Nat = 0;
        if (start > _period){
            end := Nat.sub(start, _period);
        };
        var res : [(Nat, V)] = [];
        var i = start;
        while(i <= start and i >= end){
            switch(Trie.get(_trie, keyn(i), Nat.equal)){
                case(?(v)){
                    res := ArrayTool.append(res, [(i, v)]);
                };
                case(_){};
            };
            i -= 1;
        };
        return res;
    };
    private func _natToFloat(_n: Nat) : Float{
        return Float.fromInt64(Int64.fromNat64(Nat64.fromNat(_n)));
    };
    private func keyb(t: Blob) : Trie.Key<Blob> { return { key = t; hash = Blob.hash(t) }; };
    private func keyp(t: Principal) : Trie.Key<Principal> { return { key = t; hash = Principal.hash(t) }; };
    private func keyn(t: Nat) : Trie.Key<Nat> { return { key = t; hash = Tools.natHash(t) }; };
    private func keyt(t: Text) : Trie.Key<Text> { return { key = t; hash = Text.hash(t) }; };

    private func _now() : Timestamp{
        return Int.abs(Time.now() / 1000000000);
    };
    private func _onlyOwner(_caller: Principal) : Bool { 
        return _caller == owner;
    };
    private func _onlyProvider(_caller: Provider, _sid: SeriesId) : Bool { 
        if (_caller == Principal.fromActor(this)){ return true; };
        return Option.isSome(List.find(providers, func (t: (Provider, [SeriesId], [Principal])): Bool{ 
            (_caller == t.0 or Option.isSome(Array.find(t.2, func (s:Principal):Bool{ _caller == s })))
            and Option.isSome(Array.find(t.1, func (s:SeriesId):Bool{ _sid == s or s == 0 })) 
        }));
    };
    private func _onlyAnon(_caller: Principal) : Bool{
        return Tools.principalForm(_caller) == #AnonymousId or Tools.principalForm(_caller) == #SelfAuthId;
    };
    private func _isCanister(_caller: Principal) : Bool{
        return Tools.principalForm(_caller) == #OpaqueId;
    };
    private func _getProvider(_caller: Principal) : Provider{
        switch(List.find(providers, func (t: (Provider, [SeriesId], [Principal])): Bool{ 
            _caller == t.0 or Option.isSome(Array.find(t.2, func (s:Principal):Bool{ _caller == s }))
        })){
            case(?(item)){ return item.0 };
            case(_){ assert(false) };
        };
        return Principal.fromActor(this);
    };

    private func _clearCache(_sid: SeriesId) : (){
        var info: SeriesInfo = _getSeriesInfo(_sid);
        if (info.heartbeat == 0){
            return ();
        };
        switch(Trie.get(seriesData2, keyn(_sid), Nat.equal)){
            case(?(trie)){
                let temp = Trie.filter(trie, func (k:HeartbeatId, v:[DataItem]): Bool{ _now() < k * info.heartbeat + info.cacheDuration });
                seriesData2 := Trie.put(seriesData2, keyn(_sid), Nat.equal, temp).0;
            };
            case(_){};
        };
        switch(Trie.get(requestLogs2, keyn(_sid), Nat.equal)){
            case(?(trie)){
                let temp = Trie.filter(trie, func (k:HeartbeatId, v:[Log]): Bool{ _now() < k * info.heartbeat + info.cacheDuration });
                requestLogs2 := Trie.put(requestLogs2, keyn(_sid), Nat.equal, temp).0;
            };
            case(_){};
        };
    };
    private func _chargeFee(_account: Principal, _num: Nat) : (){
        // TODO
        // free for whiltelist
        // balance[_account] - _num*fee;
    };
    private func _categoryCheck(_cat: T.Category, _sid: Nat) : Bool{
        switch(_cat){
            case(#Crypto){ (_sid > 0 and _sid <= 999) or (_sid >= 10000 and _sid <= 19999) };
            case(#Currency){ _sid >= 1000 and _sid <= 1999 };
            case(#Commodity){ _sid >= 100000 and _sid <= 199999 };
            case(#Stock){ _sid >= 200000 and _sid <= 299999 };
            case(#Economy){ _sid >= 300000 and _sid <= 399999 };
            case(#Weather){ _sid >= 1000000 and _sid <= 1999999 };
            case(#Sports){ _sid >= 2000000 and _sid <= 2999999 };
            case(#Social){ _sid >= 3000000 and _sid <= 3999999 };
            case(#Other){ _sid >= 5000000 and _sid <= 9999999 };
        };
    };
    private func _getSeries(_sid: SeriesId, _page: Nat, _periodSeconds: Nat): [(Timestamp, Nat)]{
        var info: SeriesInfo = _getSeriesInfo(_sid);
        if (info.heartbeat == 0){
            return [];
        };
        var start: Nat = _now() / info.heartbeat; // latest
        var period = _periodSeconds / info.heartbeat;
        switch(Trie.get(seriesData2, keyn(_sid), Nat.equal)){ 
            case(?(trie)){
                return Array.chain<(HeartbeatId, [DataItem]), (Timestamp, Nat)>(triePage<[DataItem]>(trie, start, _page, period), 
                    func (t: (HeartbeatId, [DataItem])): [(Timestamp, Nat)]{ 
                        var res: [(Timestamp, Nat)] = [];
                        for (item in t.1.vals()){
                            res := ArrayTool.append(res, [(item.timestamp, item.value)]);
                        };
                        return res;
                    }
                );
            };
            case(_){
                return [];
            };
        };
    };
    private func _getDataItem(_sid: SeriesId, _ts: Timestamp): ?(Timestamp, Nat){
        var info: SeriesInfo = _getSeriesInfo(_sid);
        if (info.heartbeat == 0){
            return null;
        };
        var pid = _ts / info.heartbeat;
        var index: Nat = 0;
        switch(Trie.get(seriesData2, keyn(_sid), Nat.equal)){
            case(?(trie)){
                while(pid >= _getSeriesCreationTime(_sid) / info.heartbeat){
                    switch(Trie.get(trie, keyn(pid), Nat.equal)){
                        case(?(items)){ 
                            for (i in items.keys()){
                                if (_ts >= items[i].timestamp){
                                    index := i;
                                };
                            };
                            if (items.size() > 0){
                                return ?(items[index].timestamp, items[index].value);
                            } else {
                                return null;
                            };
                        };
                        case(_){
                            pid -= 1;
                        };
                    };
                };
                return null;
            };
            case(_){
                return null;
            };
        };
    };
    private func _setDataItem(_sid: SeriesId, _pid: HeartbeatId, _value: DataItem, _isAppend: Bool): (){
        if (not(_isAppend)){
            seriesData2 := Trie.put2D(seriesData2, keyn(_sid), Nat.equal, keyn(_pid), Nat.equal, [_value]);
        }else{
            switch(Trie.get(seriesData2, keyn(_sid), Nat.equal)){
                case(?(trie)){
                    switch(Trie.get(trie, keyn(_pid), Nat.equal)){
                        case(?(items)){
                            seriesData2 := Trie.put2D(seriesData2, keyn(_sid), Nat.equal, keyn(_pid), Nat.equal, ArrayTool.append([_value], items));
                        };
                        case(_){
                            seriesData2 := Trie.put2D(seriesData2, keyn(_sid), Nat.equal, keyn(_pid), Nat.equal, [_value]);
                        };
                    };
                };
                case(_){
                    seriesData2 := Trie.put2D(seriesData2, keyn(_sid), Nat.equal, keyn(_pid), Nat.equal, [_value]);
                };
            };
        };
        // _clearCache(_sid);
    };
    private func _getLog(_sid: SeriesId, _pid: HeartbeatId): [Log]{
        switch(Trie.get(requestLogs2, keyn(_sid), Nat.equal)){
            case(?(trie)){
                switch(Trie.get(trie, keyn(_pid), Nat.equal)){
                    case(?(v)){
                        return v;
                    };
                    case(_){
                        return [];
                    };
                };
            };
            case(_){
                return [];
            };
        };
    };
    // If multiple data items are to be set in the same pid, the timestamp of the added data item must be the maximum one.
    private func _requestData(_sid: SeriesId, _pid: HeartbeatId, _item: RequestLog, _index: ?Nat): (){
        var info: SeriesInfo = _getSeriesInfo(_sid);
        assert(info.heartbeat > 0);
        assert(_item.request.timestamp <= _now() + 1);
        assert(_item.request.timestamp * 10 == _item.request.timestamp * 10 / info.heartbeat * info.heartbeat);
        var logs = _getLog(_sid, _pid);
        switch(_index){
            case(?(index)){
                let temp = Array.thaw<Log>(logs);
                temp[index] := {
                    confirmed = temp[index].confirmed;
                    requestLogs = ArrayTool.append(temp[index].requestLogs, [_item]);
                };
                logs := Array.freeze(temp);
            };
            case(_){ // new request group
                for (log in logs.vals()){
                    if (log.requestLogs.size() > 0){
                        assert(_item.request.timestamp > log.requestLogs[0].request.timestamp);
                    };
                };
                logs := ArrayTool.append([{
                    confirmed = false;
                    requestLogs = [_item];
                }], logs);
            };
        };
        requestLogs2 := Trie.put2D(requestLogs2, keyn(_sid), Nat.equal, keyn(_pid), Nat.equal, logs);
        // _clearCache(_sid);
    };
    private func _confirmData(_sid: SeriesId, _pid: HeartbeatId, _index: ?Nat): (){
        let index = Option.get(_index, 0);
        let logs = Array.thaw<Log>(_getLog(_sid, _pid));
        logs[index] := {
            confirmed = true;
            requestLogs = logs[index].requestLogs; 
        };
        requestLogs2 := Trie.put2D(requestLogs2, keyn(_sid), Nat.equal, keyn(_pid), Nat.equal, Array.freeze(logs));
    };
    private func _setWorkload(_account: Principal, _score: ?Nat, _invalid: ?Nat) : (){
        switch(Trie.get(workloads, keyp(_account), Principal.equal)){
            case(?(work)){
                let score = work.0 + Option.get(_score, 0);
                let invalid = work.1 + Option.get(_invalid, 0);
                workloads := Trie.put(workloads, keyp(_account), Principal.equal, (score, invalid)).0;
            };
            case(_){
                let score = Option.get(_score, 0);
                let invalid = Option.get(_invalid, 0);
                workloads := Trie.put(workloads, keyp(_account), Principal.equal, (score, invalid)).0;
            };
        };
    };

    private func _getDexPair(_sid: SeriesId) : ?DexPair{
        return Trie.get(dexPairs, keyn(_sid), Nat.equal);
    };
    private func _getSeriesInfo(_sid: SeriesId): SeriesInfo{
        switch(Trie.get(seriesInfo, keyn(_sid), Nat.equal)){
            case(?(item)){ return item.0 };
            case(_){ Prelude.unreachable(); };
        };
    };
    private func _getSeriesCreationTime(_sid: SeriesId): Nat{
        switch(Trie.get(seriesInfo, keyn(_sid), Nat.equal)){
            case(?(item)){ return item.1 };
            case(_){ return 0; };
        };
    };
    
    private func _getDataIndex(_sid: SeriesId, _pid: HeartbeatId, _ts: Timestamp): (exist: ?Nat){
        var itemIndex: ?Nat = null;
        var i : Nat = 0;
        label Loop for (log in _getLog(_sid, _pid).vals()){
            if (log.requestLogs.size() > 0){
                if (_ts == log.requestLogs[0].request.timestamp) {
                    itemIndex := ?i;
                    break Loop;
                };
            };
            i += 1;
        };
        return itemIndex;
    };
    private func _setData(_account: Principal, _sid: SeriesId, _request: RequestLog) : (confirmed: Bool){
        var info: SeriesInfo = _getSeriesInfo(_sid);
        assert(info.heartbeat > 0);
        assert(_request.request.timestamp * 10 == _request.request.timestamp * 10 / info.heartbeat * info.heartbeat); // A pid can only contain 10 data items
        let pid = _request.request.timestamp / info.heartbeat;
        var itemIndex : Nat = 0;
        var isExisted : Bool = false;
        let existedIndex: ?Nat = _getDataIndex(_sid, pid, _request.request.timestamp);
        if (Option.isSome(existedIndex)){
            itemIndex := Option.get(existedIndex, itemIndex);
            isExisted := true;
        };
        //check 
        assert(_now() < _request.request.timestamp + info.conDuration);
        _setWorkload(_account, ?1, null);
        var placed : Bool = false;
        if (isExisted){
            let log = _getLog(_sid, pid)[itemIndex];
            if (Option.isSome(Array.find(log.requestLogs, func (t:RequestLog):Bool{ t.provider == _request.provider }))) { placed := true; };
            if (log.confirmed) { return true; };
        };
        //put
        if (not(placed)){
            _requestData(_sid, pid, _request, existedIndex);
        };
        //cons
        return _consensus(_sid, pid, itemIndex);
    };
    private func _consensus(_sid: SeriesId, _pid: HeartbeatId, _index: Nat) : (confirmed: Bool){
        var info: SeriesInfo = _getSeriesInfo(_sid);
        assert(info.heartbeat > 0);
        let logs = _getLog(_sid, _pid);
        if (logs.size() > _index){
            let log = logs[_index];
            if (log.confirmed) { return true; } 
            else{
                var count: Nat = 0;
                var sum: Nat = 0;
                var ts: Nat = 0;
                for (request in log.requestLogs.vals()){
                    count += 1;
                    sum += request.request.value;
                    if (ts == 0){
                        ts := request.request.timestamp;
                    };
                };
                var avg = sum / count;
                var confirmed: Nat = 0;
                var newSum: Nat = 0;
                for (request in log.requestLogs.vals()){
                    if (request.request.value >= avg and Nat.sub(request.request.value, avg) * 10000 / avg <= info.conMaxDevRate ){ 
                        confirmed += 1;
                        newSum +=  request.request.value;
                    } else if (request.request.value < avg and Nat.sub(avg, request.request.value) * 10000 / avg <= info.conMaxDevRate ){ 
                        confirmed += 1; 
                        newSum +=  request.request.value;
                    };
                };
                var isAppendData: Bool = false;
                if (ts > info.heartbeat * _pid){
                    isAppendData := true;
                };
                if (confirmed >= info.conMinRequired){
                    _confirmData(_sid, _pid, ?_index);
                    _setDataItem(_sid, _pid, {timestamp = ts; value = newSum / confirmed }, isAppendData);
                    for (request in log.requestLogs.vals()){
                        if (request.request.value >= avg and Nat.sub(request.request.value, avg) * 10000 / avg <= info.conMaxDevRate ){ 
                            _setWorkload(request.provider, ?1, null);
                        } else if (request.request.value < avg and Nat.sub(avg, request.request.value) * 10000 / avg <= info.conMaxDevRate ){ 
                            _setWorkload(request.provider, ?1, null);
                        }else{
                            _setWorkload(request.provider, null, ?1);
                        };
                    };
                    return true;
                }else{
                    return false;
                };
            };
        }else{
            return false;
        };
    };
    // auto request
    private func _requestFromICDex(_sid: SeriesId, _pair: Principal, _reverse: Bool, decimals0: Nat, decimals1: Nat): async* (){
        let dex: ICDex.Self = actor(Principal.toText(_pair));
        let provider = Principal.fromActor(this);
        let liquid = await dex.liquidity(null);
        var info: SeriesInfo = _getSeriesInfo(_sid);
        assert(info.heartbeat > 0);
        switch(Trie.get(seriesInfo, keyn(_sid), Nat.equal)){
            case(?(item)){
                let decimals = item.0.decimals;
                var conversionRate: Nat = 0;
                if (not(_reverse) and liquid.value0 > 0){
                    conversionRate := (10 ** (decimals+decimals0)) * liquid.value1 / liquid.value0  / (10**decimals1);
                }else if (liquid.value1 > 0){
                    conversionRate := (10 ** (decimals+decimals1)) * liquid.value0 / liquid.value1  / (10**decimals0);
                };
                if (conversionRate > 0){
                    var req : RequestLog = {
                        request = { value = conversionRate; timestamp = _now() / info.heartbeat * info.heartbeat; };
                        provider = provider;
                        time = _now();
                        signature = null;
                    };
                    ignore _setData(provider, _sid, req);
                };
            };
            case(_){};
        };
    };
    private func _requestFromICPSwap(_sid: SeriesId, _pair: Principal, _reverse: Bool, decimals0: Nat, decimals1: Nat): async* (){
        let dex: ICPSwap.Self = actor(Principal.toText(_pair));
        let provider = Principal.fromActor(this);
        let quoteAmount : Text = Nat.toText(10 ** (if (_reverse) {decimals0} else {decimals1}));
        let liquid = await dex.quote({
                operator = Principal.fromActor(this);
                amountIn = quoteAmount;
                zeroForOne = _reverse;
                amountOutMinimum = "1";
            });
        var info: SeriesInfo = _getSeriesInfo(_sid);
        assert(info.heartbeat > 0);
        switch(liquid){
            case(#ok(baseAmount)){
                let value0 = baseAmount;
                let value1 = Option.get(Nat.fromText(quoteAmount), 0);
                let conversionRate = (10 ** (info.decimals+decimals0)) * value1 / value0  / (10**decimals1);
                if (conversionRate > 0){
                    var req : RequestLog = {
                        request = { value = conversionRate; timestamp = _now() / info.heartbeat * info.heartbeat; };
                        provider = provider;
                        time = _now();
                        signature = null;
                    };
                    ignore _setData(provider, _sid, req);
                };
            };
            case(_){};
        };
    };
    private func _requestFromDex(_sid: SeriesId, _dexName: Text, _pair: Principal, _reverse: Bool, decimals0: Nat, decimals1: Nat) : async* (){
        if (_dexName == "icdex"){
            await* _requestFromICDex(_sid, _pair, _reverse, decimals0, decimals1);
        }else if (_dexName == "icpswap"){
            await* _requestFromICPSwap(_sid, _pair, _reverse, decimals0, decimals1);
        };
    };
    // private func _requestFromDexByTokens(_sid: SeriesId, _dexName: Text, _token0: Principal, _token1: Principal, _reverse: Bool) : async* (){
    //     if (_dexName == "icdex"){
    //         let router: DexRouter.Self = actor(dexRouter); 
    //         let temp = await router.route(_token0, _token1, ?_dexName);
    //         if (temp.size() > 0){
    //             await* _requestFromICDex(_sid, temp[0].0, _reverse);
    //         };
    //     };
    // };
    private func _requestIcpXdr() : async* (){
        var sid: Nat = 1;
        let provider = Principal.fromActor(this);
        let minting: Minting.Self = actor("rkp4c-7iaaa-aaaaa-aaaca-cai");
        let icpXdr = await minting.get_icp_xdr_conversion_rate();
        var info: SeriesInfo = _getSeriesInfo(sid);
        assert(info.heartbeat > 0);
        var req : RequestLog = {
            request = { 
                value = Nat64.toNat(icpXdr.data.xdr_permyriad_per_icp); 
                timestamp = Nat64.toNat(icpXdr.data.timestamp_seconds) / info.heartbeat * info.heartbeat;
            };
            provider = provider;
            time = _now();
            signature = null;
        };
        ignore _setData(provider, sid, req);
        
        let sid2: Nat = 2;
        let info2 = _getSeriesInfo(sid2);
        assert(info2.heartbeat > 0);
        let infoXdr = _getSeriesInfo(1000); // 1000 : XDR/USD
        switch(_getDataItem(1000, _now())){ 
            case(?(xdrUsd)){
                let req2: RequestLog = {
                    request = { 
                        value = req.request.value * xdrUsd.1 * (10 ** info2.decimals) / (10 ** (info.decimals + infoXdr.decimals)); 
                        timestamp = Nat64.toNat(icpXdr.data.timestamp_seconds) / info2.heartbeat * info2.heartbeat; 
                    };
                    provider = provider;
                    time = _now();
                    signature = null;
                };
                ignore _setData(provider, sid2, req2);
            };
            case(_){};
        };
    };
    private func _fetchICDex() : async* (){ 
            for((sid, (info,time)) in Trie.iter(seriesInfo)){
                if (info.heartbeat > 0 and (_categoryCheck(#Crypto, sid) and info.sourceName == "icdex")){
                    switch(_getDexPair(sid)){
                        case(?(dex, pair, reciprocal, decimals0, decimals1)){
                            try{
                                await* _requestFromDex(sid, info.sourceName, pair, reciprocal, decimals0, decimals1);
                            } catch (err) {}; 
                        };
                        case(_){};
                    };
                };
            };
    };
    private func _fetchICPSwap() : async* (){ 
            for((sid, (info,time)) in Trie.iter(seriesInfo)){
                if (info.heartbeat > 0 and (_categoryCheck(#Crypto, sid) and info.sourceName == "icpswap")){
                    switch(_getDexPair(sid)){
                        case(?(dex, pair, reciprocal, decimals0, decimals1)){
                            try{
                                await* _requestFromDex(sid, info.sourceName, pair, reciprocal, decimals0, decimals1);
                            } catch (err) {}; 
                        };
                        case(_){};
                    };
                };
            };
    };
    // https outcalls
    private func _textToNat(txt : Text) : Nat {
        assert (txt.size() > 0);
        let chars = txt.chars();
        var num : Nat = 0;
        for (v in chars) {
            if (Char.toNat32(v) == 10 or Char.toNat32(v) == 13 or Char.toNat32(v) == 32 or Char.toNat32(v) == 44 or Char.toNat32(v) == 95){ 
                // \n \r (space) , _
                //skip
            }else {
                let charToNum = Nat32.toNat(Char.toNat32(v) - 48);
                assert (charToNum >= 0 and charToNum <= 9);
                num := num * 10 + charToNum;
            };
        };
        return num;
    };
    private func _textToFloat(txt : Text) : Float {
        //assert (txt.size() > 0);
        let chars = txt.chars();
        var num : Nat = 0;
        var res : Float = 0.0;
        var isDecimalPart : Bool = false;
        var decimalsCount : Nat = 0;
        for (v in chars) {
            if (Char.toNat32(v) == 10 or Char.toNat32(v) == 13 or Char.toNat32(v) == 32 or Char.toNat32(v) == 44 or Char.toNat32(v) == 95){ 
                // \n \r (space) , _
                //skip
            }else if (Char.toNat32(v) == 46){ //.
                isDecimalPart := true;
                res := _natToFloat(num);
            }else if (Char.toNat32(v) >= 48 and Char.toNat32(v) <= 57 ) {
                let charToNum = Nat32.toNat(Char.toNat32(v) - 48);
                assert (charToNum >= 0 and charToNum <= 9);
                if (not(isDecimalPart)){
                    num := num * 10 + charToNum;
                }else{
                    decimalsCount += 1;
                    res += _natToFloat(charToNum) / _natToFloat(10 ** decimalsCount)
                };
            };
        };
        if (not(isDecimalPart)) { res := _natToFloat(num) };
        return res;
    };
    private func _floatToNat(_data : Float, _decimals: Nat) : Nat {
        return Int.abs(Float.toInt(_data * _natToFloat(10 ** _decimals)));
    };
    public query func _call_transform(raw : IC.TransformArgs) : async IC.HttpResponsePayload {
        let transformed : IC.HttpResponsePayload = {
            status = raw.response.status;
            body = raw.response.body;
            headers = [
                { name = "Content-Security-Policy"; value = "default-src 'self'"; },
                { name = "Referrer-Policy"; value = "strict-origin" },
                { name = "Permissions-Policy"; value = "geolocation=(self)" },
                { name = "Strict-Transport-Security"; value = "max-age=63072000"; },
                { name = "X-Frame-Options"; value = "DENY" },
                { name = "X-Content-Type-Options"; value = "nosniff" },
            ];
        };
        return transformed;
    };
    private func _decodeTS(_result : IC.HttpResponsePayload) : (Text, Nat) {
        var txt : Text = "";
        switch (Text.decodeUtf8(Blob.fromArray(_result.body))) {
            case null { assert(false); return ("", 0); };
            case (?decoded) {
                var i: Nat = 0;
                for (entry in Text.split(decoded, #text("\"timestamp\": "))) {
                    if (i == 1){
                        var j: Nat = 0;
                        for (element1 in Text.split(entry, #text("\""))) {
                            if (j == 0) {
                                txt := element1;
                            };
                            j += 1;
                        };
                        if (j == 1){
                            j := 0;
                            for (element1 in Text.split(entry, #text("}"))) {
                                if (j == 0) {
                                    txt := element1;
                                };
                                j += 1;
                            };
                        };
                    };
                    i += 1;
                };
                return (txt, _textToNat(txt));
            };
        };
    };
    private func _decodeFX(_result : IC.HttpResponsePayload, _curr: Text, _decimals: Nat) : (Text, Nat) {
        var txt : Text = "";
        switch (Text.decodeUtf8(Blob.fromArray(_result.body))) {
            case null { assert(false); return ("", 0); };
            case (?decoded) {
                var i: Nat = 0;
                for (entry in Text.split(decoded, #text("\""# _curr #"\": "))) {
                    if (i == 1){
                        var j: Nat = 0;
                        for (element1 in Text.split(entry, #text(","))) {
                            if (j == 0) {
                                txt := element1;
                            };
                            j += 1;
                        };
                        if (j == 1){
                            j := 0;
                            for (element1 in Text.split(entry, #text(" }"))) {
                                if (j == 0) {
                                    txt := element1;
                                };
                                j += 1;
                            };
                        };
                    };
                    i += 1;
                };
                return (txt, _floatToNat(1 / _textToFloat(txt), _decimals));
            };
        };
    };
    private func _joinArgsFX() : Text{
        let trie = Trie.filter(seriesInfo, func (k:SeriesId, v:(SeriesInfo, Timestamp)):Bool{
            _categoryCheck(#Currency, k) and v.0.sourceName == "apilayer"
        });
        var args: Text = "";
        for ((sid, (info,ts)) in Trie.iter(trie)){
            if (args.size() > 0){ args #= "," };
            args #= info.base;
        };
        return args;
    };
    private func _fetchFX() : async* (Nat, Blob, Text,Nat){ // (Nat, Blob, Text,Nat)
        // var n1: Nat = 0;
        // var n2: Nat = 0;
        let host : Text = setting_apilayer.host;
        let request_headers = [
            { name = "Host"; value = host # ":443" },
            { name = "User-Agent"; value = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.0.0 Safari/537.36" }, // Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.0.0 Safari/537.36
            { name = "apikey"; value = setting_apilayer.key },
            //{ name = "User-Agent"; value = "PostmanRuntime/7.29.2" }
        ];
        let request : IC.HttpRequestArgs = { // "https://api.apilayer.com/fixer/latest?base=USD&symbols=XDR,EUR,GBP,JPY,AUD,CHF,NZD,CAD,HKD,CNY,KRW"
            url = Text.replace(setting_apilayer.url, #text("{SYMBOLS}"), _joinArgsFX()); //"https://api.apilayer.com/exchangerates_data/latest?base=USD&symbols=XDR,EUR,GBP,JPY,AUD,CHF,NZD,CAD,HKD,SGD,CNY,KRW,TRY,INR,RUB,MXN,ZAR,SEK,DKK,THB,VND,MYR,TWD,BRL";
            max_response_bytes = ?2000;  // ?Nat64.fromNat(MAX_RESPONSE_BYTES);
            headers = request_headers;
            body = null;
            method = #get;
            transform = ?{function = _call_transform; context = Blob.fromArray([]) };
        };
        //try {
            Cycles.add(220_000_000_000);
            let ic : IC.Self = actor ("aaaaa-aa");
            let response = await ic.http_request(request);
            // n1 := response.body.size();
            // n2 := response.status;
            let provider = Principal.fromActor(this);
            let ts = _decodeTS(response);
            let timestamp = ts.1;
            for((sid, (info,time)) in Trie.iter(seriesInfo)){
                if (info.heartbeat > 0 and (sid == 0 or (_categoryCheck(#Currency, sid) and info.sourceName == "apilayer"))){
                    try{
                        let result = _decodeFX(response, info.base, info.decimals);
                        if (result.1 > 0){
                            var req : RequestLog = {
                                request = { value = result.1; timestamp = timestamp / info.heartbeat * info.heartbeat; };
                                provider = provider;
                                time = _now();
                                signature = null;
                            };
                            ignore _setData(provider, sid, req);
                        };
                        // return (response.status, Blob.fromArray(response.body), result.0, result.1);
                    } catch (err) {};
                };
            };
            return (response.status, Blob.fromArray(response.body), request.url, ts.1);
        // } catch (err) {
        //     Debug.print(Error.message(err));
        //     return (0, Blob.fromArray([]), "Error", 0);
        // };
    };
    private func _decodeBA(_result : IC.HttpResponsePayload, _curr: Text, _decimals: Nat) : (Text, Nat) {
        var txt : Text = "";
        switch (Text.decodeUtf8(Blob.fromArray(_result.body))) {
            case null { assert(false); return ("", 0); };
            case (?decoded) {
                var i: Nat = 0;
                for (entry in Text.split(decoded, #text("\""# _curr #"\",\"price\":\""))) {
                    if (i == 1){
                        var j: Nat = 0;
                        for (element1 in Text.split(entry, #text("\"}"))) {
                            if (j == 0) {
                                txt := element1;
                            };
                            j += 1;
                        };
                    };
                    i += 1;
                };
                return (txt, _floatToNat(_textToFloat(txt), _decimals));
            };
        };
    };
    private func _joinArgsBA() : Text{
        let trie = Trie.filter(seriesInfo, func (k:SeriesId, v:(SeriesInfo, Timestamp)):Bool{
            _categoryCheck(#Crypto, k) and v.0.sourceName == "binance"
        });
        var args: Text = "";
        for ((sid, (info,ts)) in Trie.iter(trie)){
            if (args.size() > 0){ args #= "," };
            args #= "%22"# info.base # info.quote #"%22";
        };
        return args;
    };
    private func _fetchBA() : async* (Nat, Blob, Text,Nat){ // (Nat, Blob, Text,Nat)
        // var n1: Nat = 0;
        // var n2: Nat = 0;
        let host : Text = setting_binance.host;
        let request_headers = [
            { name = "Host"; value = host # ":443" },
            { name = "User-Agent"; value = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.0.0 Safari/537.36" }, // Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.0.0 Safari/537.36
            //{ name = "apikey"; value = setting_binance.key },
            //{ name = "User-Agent"; value = "PostmanRuntime/7.29.2" }
        ];
        let request : IC.HttpRequestArgs = { // Text.replace(setting_binance.url, #text("{SYMBOLS}"), _joinArgsBA()); //
            url = Text.replace(setting_binance.url, #text("{SYMBOLS}"), _joinArgsBA()); // "https://api.binance.com/api/v3/ticker/price?symbols=[%22BTCUSDT%22,%22BNBUSDT%22]";
            max_response_bytes = ?5000;
            headers = request_headers;
            body = null;
            method = #get;
            transform = ?{function = _call_transform; context = Blob.fromArray([]) };
        };
        //for debug // return (0, Blob.fromArray([]), request.url, 0);
        //try {
            Cycles.add(220_000_000_000);
            let ic : IC.Self = actor ("aaaaa-aa");
            let response = await ic.http_request(request);
            // n1 := response.body.size();
            // n2 := response.status;
            let provider = Principal.fromActor(this);
            let timestamp = _now();
            for((sid, (info,time)) in Trie.iter(seriesInfo)){
                if (info.heartbeat > 0 and _categoryCheck(#Crypto, sid) and info.sourceName == "binance"){
                    try {
                        let result = _decodeBA(response, info.base#info.quote, info.decimals);
                        if (result.1 > 0){
                            var req : RequestLog = {
                                request = { value = result.1; timestamp = timestamp / info.heartbeat * info.heartbeat; };
                                provider = provider;
                                time = _now();
                                signature = null;
                            };
                            ignore _setData(provider, sid, req);
                        };
                        // return (response.status, Blob.fromArray(response.body), result.0, result.1);
                    } catch (err) {};
                };
            };
            return (response.status, Blob.fromArray(response.body), request.url, timestamp);
        // } catch (err) {
        //     Debug.print(Error.message(err));
        //     return (0, Blob.fromArray([]), "Error", 0);
        // };
    };
    private func _decodeCMC(_result : IC.HttpResponsePayload, _curr: Text, _decimals: Nat) : (Text, Nat) {
        var txt : Text = "";
        switch (Text.decodeUtf8(Blob.fromArray(_result.body))) {
            case null { assert(false); return ("", 0); };
            case (?decoded) {
                var i: Nat = 0;
                for (entry in Text.split(decoded, #text("\""# _curr #"\""))) {
                    if (i == 1){
                        var j: Nat = 0;
                        for (element1 in Text.split(entry, #text("\"price\":"))) {
                            if (j == 1) {
                                var k: Nat = 0;
                                for (element2 in Text.split(element1, #text(","))) {
                                    if (k == 0){
                                        txt := element2;
                                    };
                                    k += 1;
                                };
                            };
                            j += 1;
                        };
                    };
                    i += 1;
                };
                return (txt, _floatToNat(_textToFloat(txt), _decimals));
            };
        };
    };
    public query func _cmc_transform(raw : IC.TransformArgs) : async IC.HttpResponsePayload {
        var txt : Text = "";
        switch (Text.decodeUtf8(Blob.fromArray(raw.response.body))) {
            case null {};
            case (?decoded) {
                var i: Nat = 0;
                for (entry in Text.split(decoded, #text("\"data\":"))) {
                    if (i == 1){
                        txt := entry;
                    };
                    i += 1;
                };
            };
        };
        let transformed : IC.HttpResponsePayload = {
            status = raw.response.status;
            body = Blob.toArray(Text.encodeUtf8(txt));
            headers = [
                { name = "Content-Security-Policy"; value = "default-src 'self'"; },
                { name = "Referrer-Policy"; value = "strict-origin" },
                { name = "Permissions-Policy"; value = "geolocation=(self)" },
                { name = "Strict-Transport-Security"; value = "max-age=63072000"; },
                { name = "X-Frame-Options"; value = "DENY" },
                { name = "X-Content-Type-Options"; value = "nosniff" },
            ];
        };
        return transformed;
    };
    private func _fetchCMC() : async* (Nat, Blob, Text,Nat){ // (Nat, Blob, Text,Nat)
        // var n1: Nat = 0;
        // var n2: Nat = 0;
        let host : Text = setting_coinmarketcap.host;
        let request_headers = [
            { name = "Host"; value = host # ":443" },
            { name = "User-Agent"; value = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.0.0 Safari/537.36" }, // Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.0.0 Safari/537.36
            { name = "CMC_PRO_API_KEY"; value = setting_coinmarketcap.key },
            //{ name = "User-Agent"; value = "PostmanRuntime/7.29.2" }
        ];
        let request : IC.HttpRequestArgs = { // Text.replace(setting_coinmarketcap.url, #text("{SYMBOLS}"), _joinArgsCMC()); //
            url = setting_coinmarketcap.url;
            max_response_bytes = ?Nat64.fromNat(MAX_RESPONSE_BYTES);
            headers = request_headers;
            body = null;
            method = #get;
            transform = ?{function = _call_transform; context = Blob.fromArray([]) };
        };
        //for debug // return (0, Blob.fromArray([]), request.url, 0);
        //try {
            Cycles.add(220_000_000_000);
            let ic : IC.Self = actor ("aaaaa-aa");
            let response = await ic.http_request(request);
            // n1 := response.body.size();
            // n2 := response.status;
            let provider = Principal.fromActor(this);
            let timestamp = _now();
            for((sid, (info,time)) in Trie.iter(seriesInfo)){
                if (info.heartbeat > 0 and _categoryCheck(#Crypto, sid) and info.sourceName == "coinmarketcap"){
                    try {
                        let result = _decodeCMC(response, info.base, info.decimals);
                        if (result.1 > 0){
                            var req : RequestLog = {
                                request = { value = result.1; timestamp = timestamp / info.heartbeat * info.heartbeat; };
                                provider = provider;
                                time = _now();
                                signature = null;
                            };
                            ignore _setData(provider, sid, req);
                        };
                        // return (response.status, Blob.fromArray(response.body), result.0, result.1);
                    } catch (err) {};
                };
            };
            return (response.status, Blob.fromArray(response.body), request.url, timestamp);
        // } catch (err) {
        //     Debug.print(Error.message(err));
        //     return (0, Blob.fromArray([]), "Error", 0);
        // };
    };
    private func _decodeCB(_result : IC.HttpResponsePayload, _curr: Text, _decimals: Nat) : (Text, Nat) {
        var txt : Text = "";
        switch (Text.decodeUtf8(Blob.fromArray(_result.body))) {
            case null { assert(false); return ("", 0); };
            case (?decoded) {
                var i: Nat = 0;
                for (entry in Text.split(decoded, #text(","))) {
                    if (i == 4){
                        txt := entry;
                    };
                    i += 1;
                };
                return (txt, _floatToNat(_textToFloat(txt), _decimals));
            };
        };
    };
    private func _fetchCB() : async* (Nat, Blob, Text,Nat){ // (Nat, Blob, Text,Nat)
        // var n1: Nat = 0;
        // var n2: Nat = 0;
        let host : Text = setting_coinbase.host;
        let request_headers = [
            { name = "Host"; value = host # ":443" },
            { name = "User-Agent"; value = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.0.0 Safari/537.36" }, // Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.0.0 Safari/537.36
            //{ name = ""; value = setting_coinbase.key },
            //{ name = "User-Agent"; value = "PostmanRuntime/7.29.2" }
        ];
        //try {
            // n1 := response.body.size();
            // n2 := response.status;
            let provider = Principal.fromActor(this);
            let timestamp = _now();
            var status: Nat = 200;
            var body: Blob = Blob.fromArray([]);
            for((sid, (info,time)) in Trie.iter(seriesInfo)){
                if (info.heartbeat > 0 and _categoryCheck(#Crypto, sid) and info.sourceName == "coinbase"){
                    var url = Text.replace(setting_coinbase.url, #text("{SYMBOL_BASE}"), info.base);
                    url := Text.replace(url, #text("{SYMBOL_QUOTE}"), info.quote);
                    let end = _now();
                    let start = Nat.sub(end, 180);
                    url := Text.replace(url, #text("{START}"), Nat.toText(start));
                    url := Text.replace(url, #text("{END}"), Nat.toText(end));
                    let request : IC.HttpRequestArgs = { //  //
                        url = url;
                        max_response_bytes = ?2000;
                        headers = request_headers;
                        body = null;
                        method = #get;
                        transform = ?{function = _call_transform; context = Blob.fromArray([]) };
                    };
                    try {
                        Cycles.add(220_000_000_000);
                        let ic : IC.Self = actor ("aaaaa-aa");
                        let response = await ic.http_request(request);
                        let result = _decodeCB(response, info.base, info.decimals);
                        if (result.1 > 0){
                            var req : RequestLog = {
                                request = { value = result.1; timestamp = timestamp / info.heartbeat * info.heartbeat; };
                                provider = provider;
                                time = _now();
                                signature = null;
                            };
                            ignore _setData(provider, sid, req);
                        };
                        status := response.status;
                        body := Blob.fromArray(response.body);
                        // return (response.status, Blob.fromArray(response.body), result.0, result.1);
                    } catch (err) {
                        status := 0;
                    };
                };
            };
            return (status, body, setting_coinbase.url, timestamp);
        // } catch (err) {
        //     Debug.print(Error.message(err));
        //     return (0, Blob.fromArray([]), "Error", 0);
        // };
    };

    // public methods
    public query func getFee() : async Nat{
        return fee;
    };
    public query func getSeriesInfo(_sid: SeriesId): async ?SeriesInfo{
        switch(Trie.get(seriesInfo, keyn(_sid), Nat.equal)){
            case(?(item)){ return ?item.0 };
            case(_){ return null; };
        };
    };
    public query(msg) func anon_getSeries(_sid: SeriesId, _page: ?Nat): async SeriesDataResponse{
        assert(_onlyAnon(msg.caller));
        var info: SeriesInfo = _getSeriesInfo(_sid);
        if (info.heartbeat == 0){
            return {name = info.name; sid = _sid; data = []; decimals = info.decimals};
        };
        let page = Option.get(_page, 1);
        let periodSeconds = info.heartbeat * 500;
        return {name = info.name; sid = _sid; data = _getSeries(_sid, page, periodSeconds); decimals = info.decimals};
    };
    public query(msg) func anon_get(_sid: SeriesId, _tsSeconds: ?Timestamp): async ?DataResponse{
        assert(_onlyAnon(msg.caller));
        var info: SeriesInfo = _getSeriesInfo(_sid);
        let ts = Option.get(_tsSeconds, _now());
        switch(_getDataItem(_sid, ts)){
            case(?(res)){ return ?{name = info.name; sid = _sid; data = res; decimals = info.decimals}; };
            case(_){ return null; };
        };
    };
    public query(msg) func anon_latest(_cat: T.Category) : async [DataResponse]{
        assert(_onlyAnon(msg.caller));
        var res: [{name: Text; sid: SeriesId; decimals: Nat; data:(Timestamp, Nat)}] = [];
        for ((sid, info) in Trie.iter(seriesInfo)){
            if (_categoryCheck(_cat, sid)){
                switch(_getDataItem(sid, _now())){
                    case(?(v)){ res := ArrayTool.append(res, [{name=info.0.name; sid=sid; decimals=info.0.decimals; data=v}]) };
                    case(_){};
                };
            };
        };
        return res;
    };
    public shared(msg) func getSeries(_sid: SeriesId, _page: ?Nat): async SeriesDataResponse{
        var info: SeriesInfo = _getSeriesInfo(_sid);
        if (info.heartbeat == 0){
            return {name = info.name; sid = _sid; data = []; decimals = info.decimals};
        };
        _chargeFee(msg.caller, 2);
        let page = Option.get(_page, 1);
        let periodSeconds = info.heartbeat * 500; // page size = 500
        return {name = info.name; sid = _sid; data = _getSeries(_sid, page, periodSeconds); decimals = info.decimals};
    };
    public shared(msg) func get(_sid: SeriesId, _tsSeconds: ?Timestamp): async ?DataResponse{
        var info: SeriesInfo = _getSeriesInfo(_sid);
        let ts = Option.get(_tsSeconds, _now());
        switch(_getDataItem(_sid, ts)){
            case(?(res)){ 
                _chargeFee(msg.caller, 1);
                return ?{name = info.name; sid = _sid; data = res; decimals = info.decimals}; 
            };
            case(_){ return null; };
        };
    };
    public shared(msg) func latest(_cat: T.Category) : async [DataResponse]{
        var res: [{name: Text; sid: SeriesId; decimals: Nat; data:(Timestamp, Nat)}] = [];
        for ((sid, info) in Trie.iter(seriesInfo)){
            if (_categoryCheck(_cat, sid)){
                switch(_getDataItem(sid, _now())){
                    case(?(v)){ 
                        _chargeFee(msg.caller, 2);
                        res := ArrayTool.append(res, [{name=info.0.name; sid=sid; decimals=info.0.decimals; data=v}]) 
                    };
                    case(_){};
                };
            };
        };
        return res;
    };
    public shared(msg) func volatility(_sid: SeriesId, _period: Nat): async VolatilityResponse{
        var info: SeriesInfo = _getSeriesInfo(_sid);
        assert(info.heartbeat > 0);
        assert(_period <= info.heartbeat * 4320); // 1min*4320 = 3d   5min*4320 = 15d
        let s = _getSeries(_sid, 1, _period);
        var count: Nat = 0;
        var sum: Nat = 0;
        var open: Nat = 0;
        var high: Nat = 0;
        var low: Nat = 0;
        var close: Nat = 0;
        var avg: Nat = 0;
        for ((ts,v) in s.vals()){
            count += 1;
            sum += v;
            if (count == 1) { open := v; };
            if (v > high) { high := v; };
            if (v < low or low == 0){ low := v; };
            close := v;
        };
        var res: Float = 0;
        if (count > 0 and sum > 0){
            avg := sum / count;
            res := _natToFloat(high - low) / _natToFloat(avg);
            _chargeFee(msg.caller, 3);
        };
        return {open = open; high = high; low = low; close = close; average = avg; percent = res; decimals = info.decimals};
    };
    public query func getLog(_sid: SeriesId, _tsSeconds: ?Timestamp): async [Log]{
        let ts = Option.get(_tsSeconds, _now());
        var info: SeriesInfo = _getSeriesInfo(_sid);
        assert(info.heartbeat > 0);
        let pid = ts / info.heartbeat;
        return _getLog(_sid, pid);
    };
    // request '(0, record{value=12751; timestamp=1665583587;}, null)'
    public shared(msg) func request(_sid: SeriesId, _data: DataItem, signature: ?Blob) : async (confirmed: Bool){
        assert(_onlyProvider(msg.caller, _sid));
        let provider = _getProvider(msg.caller);
        var info: SeriesInfo = _getSeriesInfo(_sid);
        assert(info.heartbeat > 0);
        let req : RequestLog = {
            request = { value = _data.value; timestamp = _data.timestamp / info.heartbeat * info.heartbeat; };
            provider = provider;
            time = _now();
            signature = signature;
        };
        return _setData(provider, _sid, req);
    };
    public query func getWorkload(_account: Provider) : async ?(score: Nat, invalid: Nat){
        return Trie.get(workloads, keyp(_account), Principal.equal);
    };

    // Debug
    public shared(msg) func debug_fetchFX() : async (Nat, Blob, Text, Nat){ // (Nat, Blob, Text, Nat)
        assert(_onlyOwner(msg.caller));
        return await* _fetchFX();
    };
    public shared(msg) func debug_fetchBA() : async (Nat, Blob, Text, Nat){ // (Nat, Blob, Text, Nat) //ip4
        assert(_onlyOwner(msg.caller));
        return await* _fetchBA();
    };
    public shared(msg) func debug_fetchCB() : async (Nat, Blob, Text, Nat){ // (Nat, Blob, Text, Nat)
        assert(_onlyOwner(msg.caller));
        return await* _fetchCB();
    };
    public shared(msg) func debug_fetchCMC() : async (Nat, Blob, Text, Nat){ // (Nat, Blob, Text, Nat) //ip4
        assert(_onlyOwner(msg.caller));
        return await* _fetchCMC();
    };
    public shared(msg) func debug_requestIcpXdr() : async (){
        assert(_onlyOwner(msg.caller));
        await* _requestIcpXdr();
    };
    public shared(msg) func debug_requestDex() : async (){
        assert(_onlyOwner(msg.caller));
        await* _fetchICDex();
        await* _fetchICPSwap();
    };
    

    // Governance

    // Manage 
    public shared(msg) func setFee(_fee: Nat) : async (){
        assert(_onlyOwner(msg.caller));
        fee := _fee;
    };
    // setApi '("apilayer", record{name="apilayer"; host="api.apilayer.com"; url="https://api.apilayer.com/fixer/latest?base=USD&symbols={SYMBOLS}"; key="......"})'        // {SYMBOLS} = XDR,EUR,GBP,JPY
    // setApi '("binance", record{name="binance"; host="api.binance.com"; url="https://api.binance.com/api/v3/ticker/price?symbols=[{SYMBOLS}]"; key=""})'        // {SYMBOLS} = %22BTCUSDT%22,%22BNBUSDT%22
    // setApi '("coinmarketcap", record{name="coinmarketcap"; host="pro.coinmarketcap.com"; url="https://pro-api.coinmarketcap.com/v1/cryptocurrency/listings/latest?start=1&limit=50&convert=USD"; key="......"})'  
    // setApi '("coinbase", record{name="coinbase"; host="api.pro.coinbase.com"; url="https://api.pro.coinbase.com/products/{SYMBOL_BASE}-{SYMBOL_QUOTE}/candles?start={START}&end={END}&granularity=60"; key=""})'  
    // // setApi '("coinbase", record{name="coinbase"; host="api.exchange.coinbase.com"; url="https://api.exchange.coinbase.com/products/{SYMBOL_BASE}-{SYMBOL_QUOTE}/ticker"; key=""})'  
    public shared(msg) func setApi(_type: Text, _value: T.OutCallAPI) : async Bool{
        assert(_onlyOwner(msg.caller));
        if (_type == "apilayer"){
            setting_apilayer := _value;
            return true;
        } else if (_type == "binance"){
            setting_binance := _value;
            return true;
        } else if (_type == "coinbase"){
            setting_coinbase := _value;
            return true;
        } else if (_type == "coinmarketcap"){
            setting_coinmarketcap := _value;
            return true;
        };
        return false;
    };
    public shared(msg) func setProvider(_account: Provider, _sids: [SeriesId], _agents: [Principal]) : async (){
        assert(_onlyOwner(msg.caller));
        providers := List.push((_account, _sids, _agents), providers);
    };
    public shared(msg) func addProviderSid(_account: Provider, _sid: SeriesId) : async (){
        assert(_onlyOwner(msg.caller));
        switch(List.find(providers, func (t: (Provider, [SeriesId], [Principal])): Bool{ _account == t.0 })){
            case(?(provider)){ 
                providers := List.filter(providers, func (t: (Provider,[SeriesId], [Principal])): Bool{ t.0 != _account });
                providers := List.push((provider.0, ArrayTool.append(provider.1, [_sid]), provider.2), providers); 
            };
            case(_){ assert(false); };
        };
    };
    public shared(msg) func delProviderSid(_account: Provider, _sid: SeriesId) : async (){
        assert(_onlyOwner(msg.caller));
        switch(List.find(providers, func (t: (Provider, [SeriesId], [Principal])): Bool{ _account == t.0 })){
            case(?(provider)){ 
                providers := List.filter(providers, func (t: (Provider,[SeriesId], [Principal])): Bool{ t.0 != _account });
                providers := List.push((provider.0, Array.filter(provider.1, func (t: SeriesId): Bool{ t != _sid }), provider.2), providers); 
            };
            case(_){ assert(false); };
        };
    };
    public shared(msg) func addProviderAgent(_account: Provider, _agent: Principal) : async (){
        assert(_onlyOwner(msg.caller));
        switch(List.find(providers, func (t: (Provider, [SeriesId], [Principal])): Bool{ _account == t.0 })){
            case(?(provider)){ 
                providers := List.filter(providers, func (t: (Provider,[SeriesId], [Principal])): Bool{ t.0 != _account });
                providers := List.push((provider.0, provider.1, ArrayTool.append(provider.2, [_agent])), providers); 
            };
            case(_){ assert(false); };
        };
    };
    public shared(msg) func delProviderAgent(_account: Provider, _agent: Principal) : async (){
        assert(_onlyOwner(msg.caller));
        switch(List.find(providers, func (t: (Provider, [SeriesId], [Principal])): Bool{ _account == t.0 })){
            case(?(provider)){ 
                providers := List.filter(providers, func (t: (Provider,[SeriesId], [Principal])): Bool{ t.0 != _account });
                providers := List.push((provider.0, provider.1, Array.filter(provider.2, func (t: Principal): Bool{ t != _agent })), providers); 
            };
            case(_){ assert(false); };
        };
    };
    public shared(msg) func removeProvider(_account: Provider) : async (){
        assert(_onlyOwner(msg.caller));
        providers := List.filter(providers, func (t: (Provider,[SeriesId], [Principal])): Bool{ t.0 != _account });
    };
    public shared(msg) func setDexPair(_sid: SeriesId, _pairInfo: DexPair) : async (){
        assert(_onlyOwner(msg.caller));
        dexPairs := Trie.put(dexPairs, keyn(_sid), Nat.equal, _pairInfo).0;
    };
    public shared(msg) func newSeriesInfo(_sid: SeriesId, _info: SeriesInfo): async Bool{
        assert(_onlyOwner(msg.caller));
        assert(Option.isNull(Trie.get(seriesInfo, keyn(_sid), Nat.equal)));
        seriesInfo := Trie.put(seriesInfo, keyn(_sid), Nat.equal, (_info, _now())).0;
        if (_sid > index) { index := _sid };
        return true;
    };
    public shared(msg) func updateSeriesInfo(_sid: SeriesId, _info: SeriesInfo, _resetData: Bool): async Bool{
        assert(_onlyOwner(msg.caller));
        assert(Option.isSome(Trie.get(seriesInfo, keyn(_sid), Nat.equal)));
        seriesInfo := Trie.put(seriesInfo, keyn(_sid), Nat.equal, (_info, _getSeriesCreationTime(_sid))).0;
        if (_resetData){
            seriesData2 := Trie.remove(seriesData2, keyn(_sid), Nat.equal).0;
        };
        return true;
    };
    public shared(msg) func delSeriesData(_sid: SeriesId): async Bool{
        assert(_onlyOwner(msg.caller));
        assert(Option.isSome(Trie.get(seriesInfo, keyn(_sid), Nat.equal)));
        seriesInfo := Trie.remove(seriesInfo, keyn(_sid), Nat.equal).0;
        seriesData2 := Trie.remove(seriesData2, keyn(_sid), Nat.equal).0;
        return true;
    };


    /// receive cycles
    public func wallet_receive(): async (){
        let amout = Cycles.available();
        let accepted = Cycles.accept(amout);
    };

    // http request
    // public shared func http_request_update(request : ICHTTP.HttpRequest) : async ICHTTP.HttpResponse {
    //     {
    //     status_code = 200;
    //     headers = [];
    //     body = Text.encodeUtf8("Response to " # request.method # " request (update)");
    //     streaming_strategy = null;
    //     upgrade = null;
    //     };
    // };
    public query func http_request(req : ICHTTP.HttpRequest) : async ICHTTP.HttpResponse {
        switch (req.method, not Option.isNull(Array.find(req.headers, ICHTTP.isGzip)), req.url) {
        case ("GET", _, path) {
            var i: Nat = 0;
            var baseToken : Text = "";
            var quoteToken : Text = "";
            for (entry in Text.split(path, #text("/"))) {
                if (entry.size() > 0){
                    if (i == 0){
                        baseToken := entry;
                    };
                    if (i == 1){
                        quoteToken := entry;
                    };
                    i += 1;
                };
            };
            let ts = _now();
            var response: Text = "";
            var sids : [Nat] = [];
            var error: Bool = false;
            if (baseToken.size() > 0 and quoteToken.size() > 0){
                let s = Trie.filter(seriesInfo, func (k: Nat, v: (SeriesInfo, Timestamp)): Bool{
                    v.0.base == baseToken and v.0.quote == quoteToken
                });
                if (Trie.size(s) == 0){
                    error := true; 
                    response := "{\"error\": {\"code\": 400, \"message\": \"Unavailable data\"}}";
                }else{
                    for ((k,v) in Trie.iter(s)){
                        sids := ArrayTool.append(sids, [k]);
                    };
                };
            }else {
                try{
                    sids := ArrayTool.append(sids, [_textToNat(Text.replace(path, #text("/"), ""))]);
                }catch(e){
                    error := true; 
                    response := "{\"error\": {\"code\": 400, \"message\": \"Unavailable data\"}}";
                };
            };
            var status: Nat16 = 200;
            if (not(error)){
                var resData: Text = "";
                for (sid in sids.vals()){
                    try{
                        var info: SeriesInfo = _getSeriesInfo(sid);
                        switch(_getDataItem(sid, ts)){
                            case(?(timestamp, value)){ 
                                if (resData.size() > 0) { resData #= ", " };
                                resData #= "{\"name\": \""# info.name #"\", \"sid\": \""# Nat.toText(sid) #"\", \"base\": \""# info.base #"\", \"quote\": \""# info.quote #"\", \"rate\": "# Float.toText(_natToFloat(value) / _natToFloat(10 ** info.decimals)) #", \"timestamp\": "# Nat.toText(timestamp) #" }"; 
                            };
                            case(_){};
                        };
                    }catch(e){ };
                };
                if (resData.size() > 0){
                    response := "{\"success\": [" # resData # "]}";
                }else{
                    status := 400;
                    response := "{\"error\": {\"code\": 400, \"message\": \"Unavailable data\"}}";
                };
            }else{
                status := 400;
                response := "{\"error\": {\"code\": 400, \"message\": \"Unavailable data\"}}";
            };
            return {
                status_code = status;
                headers = [ ("content-type", "application/json") ];
                body = Text.encodeUtf8(response);
                streaming_strategy = null;
                upgrade = null;
            };
        };
        case ("POST", _, _) {{
            status_code = 204;
            headers = [];
            body = "";
            streaming_strategy = null;
            upgrade = ?true;
        }};
        case _ {{
            status_code = 400;
            headers = [];
            body = "Invalid request";
            streaming_strategy = null;
            upgrade = null;
        }};
        }
    };

    // heartbeat
    private var LastUpdated_IcpXdr: Nat = 0;
    private func _heartbeat_fetchIcpXdr() : async (){
        let hbid = Int.abs(Time.now()) / 600000000000; // 600s
        if (hbid > LastUpdated_IcpXdr and Int.abs(Time.now()) >= hbid * 600000000000 + 60000000000 ){ // 60s
            LastUpdated_IcpXdr := hbid;
            await* _requestIcpXdr();
        };
    };
    public shared(msg) func test_heartbeat_fetchIcpXdr() : async (Nat){
        assert(_onlyOwner(msg.caller));
        await _heartbeat_fetchIcpXdr();
        return LastUpdated_IcpXdr;
    };
    private var LastUpdated_dex: Nat = 0;
    private func _heartbeat_fetchDex() : async (){
        let hbid = Int.abs(Time.now()) / 180000000000; // 3mins
        if (hbid > LastUpdated_dex and Int.abs(Time.now()) >= hbid * 180000000000 ){
            LastUpdated_dex := hbid;
            try{
                await* _fetchICDex();
            }catch(e){};
            try{
                await* _fetchICPSwap();
            }catch(e){};
        };
    };
    public shared(msg) func test_heartbeat_fetchDex() : async (Nat){
        assert(_onlyOwner(msg.caller));
        await _heartbeat_fetchDex();
        return LastUpdated_dex;
    };
    private var LastUpdated_FX: Nat = 0;
    private stable var Retry_FX: Time.Time = 0;
    private func _heartbeat_fetchFX() : async (){
        let hbid = Int.abs(Time.now()) / 3600000000000; // 1h
        if (hbid > LastUpdated_FX and Int.abs(Time.now()) >= hbid * 3600000000000 + 60000000000 ){ // 60s
            LastUpdated_FX := hbid;
            if ((await* _fetchFX()).0 == 0){
                Retry_FX := Time.now();
            };
        };
        if (Retry_FX > 0 and Time.now() > Retry_FX + 10000000000){ // 10s
            Retry_FX := 0;
            ignore await* _fetchFX();
        };
    };
    public shared(msg) func test_heartbeat_fetchFX() : async (Nat){
        assert(_onlyOwner(msg.caller));
        await _heartbeat_fetchFX();
        return LastUpdated_FX;
    };
    private var LastUpdated_BA: Nat = 0;
    private stable var Retry_BA: Time.Time = 0;
    private func _heartbeat_fetchBA() : async (){
        let hbid = Int.abs(Time.now()) / 600000000000; // 10min
        if (hbid > LastUpdated_BA){ // 
            LastUpdated_BA := hbid;
            if ((await* _fetchBA()).0 == 0){
                Retry_BA := Time.now();
            };
        };
        if (Retry_BA > 0 and Time.now() > Retry_BA + 2000000000){ // 2s
            Retry_BA := 0;
            ignore await* _fetchBA();
        };
    };
    public shared(msg) func test_heartbeat_fetchBA() : async (Nat){
        assert(_onlyOwner(msg.caller));
        await _heartbeat_fetchBA();
        return LastUpdated_BA;
    };
    private var LastUpdated_CMC: Nat = 0;
    private stable var Retry_CMC: Time.Time = 0;
    private func _heartbeat_fetchCMC() : async (){
        let hbid = Int.abs(Time.now()) / 3600000000000; // 1h
        if (hbid > LastUpdated_CMC){ // 
            LastUpdated_CMC := hbid;
            if ((await* _fetchCMC()).0 == 0){
                Retry_CMC := Time.now();
            };
        };
        if (Retry_CMC > 0 and Time.now() > Retry_CMC + 5000000000){ // 5s
            Retry_CMC := 0;
            ignore await* _fetchCMC();
        };
    };
    public shared(msg) func test_heartbeat_fetchCMC() : async (Nat){
        assert(_onlyOwner(msg.caller));
        await _heartbeat_fetchCMC();
        return LastUpdated_CMC;
    };
    private var LastUpdated_CB: Nat = 0;
    private stable var Retry_CB: Time.Time = 0;
    private func _heartbeat_fetchCB() : async (){
        let hbid = Int.abs(Time.now()) / 3600000000000; // 1h
        if (hbid > LastUpdated_CB){ //
            LastUpdated_CB := hbid;
            if ((await* _fetchCB()).0 == 0){
                Retry_CB := Time.now();
            };
        };
        if (Retry_CB > 0 and Time.now() > Retry_CB + 5000000000){ // 5s
            Retry_CB := 0;
            ignore await* _fetchCB();
        };
    };
    public shared(msg) func test_heartbeat_fetchCB() : async (Nat){
        assert(_onlyOwner(msg.caller));
        await _heartbeat_fetchCB();
        return LastUpdated_CB;
    };

    private func timer_fun() : async (){
        let f1 = _heartbeat_fetchDex();
        let f2 = _heartbeat_fetchFX();
        let f3 = _heartbeat_fetchIcpXdr();
        let f4 = _heartbeat_fetchCB();
        // try { await* _heartbeat_fetchDex(); }catch(e){};
        // try { await* _heartbeat_fetchFX(); }catch(e){};
        // try { await* _heartbeat_fetchIcpXdr(); }catch(e){};
        // //try { await* _heartbeat_fetchBA(); }catch(e){};
        // //try { await* _heartbeat_fetchCMC(); }catch(e){};
        // try { await* _heartbeat_fetchCB(); }catch(e){};
    };
    private var timer_id: Nat = 0;
    public shared(msg) func timer_start(_interval: Nat): async (){
        assert(_onlyOwner(msg.caller));
        Timer.cancelTimer(timer_id);
        timer_id := Timer.recurringTimer(#seconds(_interval), timer_fun);
    };
    public shared(msg) func timer_stop(): async (){
        assert(_onlyOwner(msg.caller));
        Timer.cancelTimer(timer_id);
    };

    system func preupgrade() {
        Timer.cancelTimer(timer_id);
    };
    system func postupgrade() {
        timer_id := Timer.recurringTimer(#seconds(60), timer_fun);
        // if (Trie.size(seriesData2) == 0){
        //     for ((sid, data) in Trie.iter(seriesData)){
        //         for ((hid, item) in Trie.iter(data)){
        //             seriesData2 := Trie.put2D(seriesData2, keyn(sid), Nat.equal, keyn(hid), Nat.equal, [item]);
        //         };
        //     };
        // };
        // if (Trie.size(requestLogs2) == 0){
        //     for ((sid, data) in Trie.iter(requestLogs)){
        //         for ((hid, item) in Trie.iter(data)){
        //             requestLogs2 := Trie.put2D(requestLogs2, keyn(sid), Nat.equal, keyn(hid), Nat.equal, [item]);
        //         };
        //     };
        // };
    };

};