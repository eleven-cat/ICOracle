/**
 * Module     : ICOracle.mo
 * Author     : ICOracle Team
 * Stability  : Experimental
 * Description: Decentralized oracle network on IC blockchain.
 * Refers     : https://github.com/eleven-cat/ICOracle
 */

import Array "mo:base/Array";
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
import Trie "./lib/Trie";
import Tools "./lib/ICLighthouse/Tools";
import Minting "./lib/CyclesMinting";
import DRC207 "./lib/ICLighthouse/DRC207";
import IC "./lib/IC";
import ICSRouter "./lib/ICLighthouse/ICSwapRouter";
import ICSwap "./lib/ICLighthouse/ICSwap";
import ICDex "./lib/ICLighthouse/ICDexTypes";
import Sonic "./lib/Sonic/Sonic";
import ICPSwap "./lib/ICPSwap/ICPSwap";
// import CertifiedData "mo:base/CertifiedData";

shared(installMsg) actor class ICOracle() = this {
    type Provider = T.Provider;
    type SeriesId = T.SeriesId;
    type HeartbeatId = T.HeartbeatId; // interval: [start, end)
    type Timestamp = T.Timestamp; // seconds
    type SeriesInfo = T.SeriesInfo;
    type DataItem = T.DataItem;
    type RequestLog = T.RequestLog;
    type Log = T.Log;
    type DataResponse = T.DataResponse;
    type VolatilityResponse = T.VolatilityResponse;

    // Variables
    private let version_: Text = "0.5";
    private let name_: Text = "ICOracle";
    private let tokenCanister = "imeri-bqaaa-aaaai-qnpla-cai"; // $OT
    private let icswapRouter = "j4d4d-pqaaa-aaaak-aanxq-cai";
    private let icdexRouter = "ltyfs-qiaaa-aaaak-aan3a-cai";
    private let sonicRouter = "3xwpq-ziaaa-aaaah-qcn4a-cai";
    private let MAX_RESPONSE_BYTES = 2 * 1024 * 1024;
    private stable var fee: Nat = 0; //  100000000 OT 
    private stable var owner: Principal = installMsg.caller;
    private stable var providers = List.nil<(Provider, [SeriesId], [Principal])>();
    private stable var workloads: Trie.Trie<Provider, (score: Nat, invalid: Nat)> = Trie.empty();
    private stable var index: Nat = 3;
    private stable var seriesInfo: Trie.Trie<SeriesId, (SeriesInfo, Timestamp)> = Trie.empty();
    private stable var series: Trie.Trie2D<SeriesId, HeartbeatId, Nat> = Trie.empty();
    private stable var logs: Trie.Trie2D<SeriesId, HeartbeatId, Log> = Trie.empty();
    private stable var dexs: Trie.Trie<Text, Principal> = Trie.empty();

    // query from trie
    private func triePage<V>(_trie: Trie.Trie<Nat,V>, _start: Nat, _page: Nat, _period: Nat) : [(Nat, V)] {
        if (_page < 1 or _period < 1){
            return [];
        };
        let offset = Nat.sub(_page, 1) * _period;
        if (offset >= _start){
            return [];
        };
        let start = Nat.sub(_start, offset);
        var end: Nat = 0;
        if (start > _period){
            end := Nat.sub(start, _period);
        };
        let trie = Trie.filter<Nat, V>(_trie, func (k:Nat, v:V): Bool{ k >= end and k <= start });
        return Iter.toArray(Trie.iter(trie));
        // let arr = Array.filter(Iter.toArray(Trie.iter(_trie)), func (t:(Nat,V)): Bool{ t.0 >= end and t.0 <= start; });
        // return arr;
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
        return Tools.principalForm(_caller) == #AnonymousId;
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
        switch(Trie.get(series, keyn(_sid), Nat.equal)){
            case(?(trie)){
                let temp = Trie.filter(trie, func (k:HeartbeatId, v:Nat): Bool{ _now() < k * info.heartbeat + info.cacheDuration });
                series := Trie.put(series, keyn(_sid), Nat.equal, temp).0;
            };
            case(_){};
        };
        switch(Trie.get(logs, keyn(_sid), Nat.equal)){
            case(?(trie)){
                let temp = Trie.filter(trie, func (k:HeartbeatId, v:Log): Bool{ _now() < k * info.heartbeat + info.conDuration });
                logs := Trie.put(logs, keyn(_sid), Nat.equal, temp).0;
            };
            case(_){};
        };
    };
    private func _chargeFee(_account: Principal, _num: Nat) : (){
        // free for whiltelist
        // balance[_account] - _num*fee;
    };
    private func _getSeries(_sid: SeriesId, _page: Nat, _periodSeconds: Nat): [(Timestamp, Nat)]{
        var info: SeriesInfo = _getSeriesInfo(_sid);
        if (info.heartbeat == 0){
            return [];
        };
        var start: Nat = _now() / info.heartbeat;
        var period = _periodSeconds / info.heartbeat + 1;
        switch(Trie.get(series, keyn(_sid), Nat.equal)){ 
            case(?(trie)){
                return Array.map<(HeartbeatId, Nat), (Timestamp, Nat)>(triePage<Nat>(trie, start, _page, period), 
                    func (t: (HeartbeatId, Nat)): (Timestamp, Nat){ (t.0 * info.heartbeat, t.1) }
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
        switch(Trie.get(series, keyn(_sid), Nat.equal)){
            case(?(trie)){
                while(pid >= _getSeriesCreationTime(_sid) / info.heartbeat){
                    switch(Trie.get(trie, keyn(pid), Nat.equal)){
                        case(?(v)){ return ?(pid * info.heartbeat, v); };
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
    private func _setDataItem(_sid: SeriesId, _pid: HeartbeatId, _value: Nat): (){
        series := Trie.put2D(series, keyn(_sid), Nat.equal, keyn(_pid), Nat.equal, _value);
        _clearCache(_sid);
    };
    private func _getLog(_sid: SeriesId, _pid: HeartbeatId): ?Log{
        switch(Trie.get(logs, keyn(_sid), Nat.equal)){
            case(?(trie)){
                switch(Trie.get(trie, keyn(_pid), Nat.equal)){
                    case(?(v)){
                        return ?v;
                    };
                    case(_){
                        return null;
                    };
                };
            };
            case(_){
                return null;
            };
        };
    };
    private func _requestData(_sid: SeriesId, _pid: HeartbeatId, _item: RequestLog): (){
        switch(_getLog(_sid, _pid)){
            case(?(log)){
                logs := Trie.put2D(logs, keyn(_sid), Nat.equal, keyn(_pid), Nat.equal, {
                    confirmed = log.confirmed;
                    requestLogs = Tools.arrayAppend(log.requestLogs, [_item]);
                });
            };
            case(_){
                logs := Trie.put2D(logs, keyn(_sid), Nat.equal, keyn(_pid), Nat.equal, {
                    confirmed = false;
                    requestLogs = [_item]; 
                });
            };
        };
        _clearCache(_sid);
    };
    private func _confirmData(_sid: SeriesId, _pid: HeartbeatId): (){
        switch(_getLog(_sid, _pid)){
            case(?(log)){
                logs := Trie.put2D(logs, keyn(_sid), Nat.equal, keyn(_pid), Nat.equal, {
                    confirmed = true;
                    requestLogs = log.requestLogs; 
                });
            };
            case(_){};
        };
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
    private func _getSeriesInfo(_sid: SeriesId): SeriesInfo{
        var info: SeriesInfo = {
            name = "";
            decimals = 0;
            heartbeat = 0; // seconds
            conMaxDevRate = 0; // ‱ permyriad
            conMinRequired = 0;
            conDuration = 0;
            cacheDuration = 0;
        };
        switch(Trie.get(seriesInfo, keyn(_sid), Nat.equal)){
            case(?(item)){ return item.0 };
            case(_){ assert(false); return info; };
        };
    };
    private func _getSeriesCreationTime(_sid: SeriesId): Nat{
        switch(Trie.get(seriesInfo, keyn(_sid), Nat.equal)){
            case(?(item)){ return item.1 };
            case(_){ return 0; };
        };
    };
    
    private func _setData(_account: Principal, _sid: SeriesId, _request: RequestLog) : (confirmed: Bool){
        var info: SeriesInfo = _getSeriesInfo(_sid);
        if (info.heartbeat == 0){
            assert(false);
        };
        let pid = _request.request.timestamp / info.heartbeat;
        //check 
        assert(_now() < _request.request.timestamp + info.conDuration);
        _setWorkload(_account, ?1, null);
        switch(_getLog(_sid, pid)){
            case(?(log)){
                if (Option.isSome(Array.find(log.requestLogs, func (t:RequestLog):Bool{ t.provider == _request.provider }))) { assert(false); };
                if (log.confirmed) { return true; };
            };
            case(_){};
        };
        //put
        _requestData(_sid, pid, _request);
        //cons
        return _consensus(_sid, pid);
    };
    private func _consensus(_sid: SeriesId, _pid: HeartbeatId) : (confirmed: Bool){
        var info: SeriesInfo = _getSeriesInfo(_sid);
        if (info.heartbeat == 0){
            assert(false);
        };
        switch(_getLog(_sid, _pid)){
            case(?(log)){
                if (log.confirmed) { return true; } 
                else{
                    var count: Nat = 0;
                    var sum: Nat = 0;
                    for (request in log.requestLogs.vals()){
                        count += 1;
                        sum += request.request.value;
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
                    if (confirmed >= info.conMinRequired){
                        _confirmData(_sid, _pid);
                        _setDataItem(_sid, _pid, newSum / confirmed);
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
            };
            case(_){ return false; };
        };
    };
    // auto request
    private func _requestFromICSwap(_sid: SeriesId, _pair: Principal, _reverse: Bool): async (){
        let dex: ICSwap.Self = actor(Principal.toText(_pair));
        let provider = Principal.fromActor(this);
        let liquid = await dex.liquidity(null);
        switch(Trie.get(seriesInfo, keyn(_sid), Nat.equal)){
            case(?(item)){
                let decimals = item.0.decimals;
                var conversionRate: Nat = 0;
                if (not(_reverse) and liquid.value0 > 0){
                    conversionRate := (10**decimals) * liquid.value1 / liquid.value0;
                }else if (liquid.value1 > 0){
                    conversionRate := (10**decimals) * liquid.value0 / liquid.value1;
                };
                if (conversionRate > 0){
                    var req : RequestLog = {
                        request = { value = conversionRate; timestamp = _now(); };
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
    private func _requestFromDex(_sid: SeriesId, _dexName: Text, _pair: Principal, _reverse: Bool) : async (){
        if (_dexName == "icswap"){
            await _requestFromICSwap(_sid, _pair, _reverse);
        };
    };
    private func _requestFromDexByTokens(_sid: SeriesId, _dexName: Text, _token0: Principal, _token1: Principal, _reverse: Bool) : async (){
        if (_dexName == "icswap"){
            let router: ICSRouter.Self = actor(icswapRouter); 
            let temp = await router.route(_token0, _token1, ?_dexName);
            if (temp.size() > 0){
                await _requestFromICSwap(_sid, temp[0].0, _reverse);
            };
        };
    };
    private func _requestIcpXdr() : async (){
        var sid: Nat = 1;
        let provider = Principal.fromActor(this);
        let minting: Minting.Self = actor("rkp4c-7iaaa-aaaaa-aaaca-cai");
        let icpXdr = await minting.get_icp_xdr_conversion_rate();
        var req : RequestLog = {
            request = { value = Nat64.toNat(icpXdr.data.xdr_permyriad_per_icp); timestamp = Nat64.toNat(icpXdr.data.timestamp_seconds); };
            provider = provider;
            time = _now();
            signature = null;
        };
        ignore _setData(provider, sid, req);
        sid := 2;
        switch(_getDataItem(0, _now())){
            case(?(xdrUsd)){
                req := {
                    request = { value = req.request.value * xdrUsd.1 / 10000; timestamp = Nat64.toNat(icpXdr.data.timestamp_seconds); };
                    provider = provider;
                    time = _now();
                    signature = null;
                };
                ignore _setData(provider, sid, req);
            };
            case(_){};
        };
    };
    // https outcalls
    public query func _xe_transform(raw : IC.CanisterHttpResponsePayload) : async IC.CanisterHttpResponsePayload {
        var txt : Text = "";
        switch (Text.decodeUtf8(Blob.fromArray(raw.body))) {
            case null {};
            case (?decoded) {
                var i: Nat = 0;
                for (entry in Text.split(decoded, #text("<p class=\"result__BigRate-sc-1bsijpp-1 iGrAod\">"))) {
                    if (i == 1){
                        var j: Nat = 0;
                        for (element1 in Text.split(entry, #text("<span class=\"faded-digits\">"))) {
                            if (j == 0) {
                                txt := element1;
                            };
                            if (j == 1) {
                                var k: Nat = 0;
                                for (element2 in Text.split(element1, #text("</span> US Dollars</p>"))) {
                                    if (k == 0) {
                                        txt #= element2;
                                    };
                                    k += 1;
                                };
                            };
                            j += 1;
                        };
                    };
                    i += 1;
                };
            };
        };
        let transformed : IC.CanisterHttpResponsePayload = {
            status = raw.status;
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
    private func _textToNat(txt : Text) : Nat {
        assert (txt.size() > 0);
        let chars = txt.chars();
        var num : Nat = 0;
        for (v in chars) {
            if (Char.toNat32(v) != 32 and Char.toNat32(v) != 44){ // (space) ,
                let charToNum = Nat32.toNat(Char.toNat32(v) - 48);
                assert (charToNum >= 0 and charToNum <= 9);
                num := num * 10 + charToNum;
            };
        };
        return num;
    };
    private func _textFloatToNat(txt : Text, decimals: Nat) : Nat {
        assert (txt.size() > 0);
        let chars = txt.chars();
        var num : Nat = 0;
        var decimalsCount: Nat = 0;
        var turnOnCounter : Bool = false;
        for (v in chars) {
            if (Char.toNat32(v) == 32 or Char.toNat32(v) == 44){ // (space) ,
                //skip
            }else if (Char.toNat32(v) == 46){ //.
                turnOnCounter := true;
            }else if (decimalsCount < decimals){
                let charToNum = Nat32.toNat(Char.toNat32(v) - 48);
                assert (charToNum >= 0 and charToNum <= 9);
                num := num * 10 + charToNum;
                if (turnOnCounter) { decimalsCount += 1; };
            };
        };
        while (decimalsCount < decimals){
            decimalsCount += 1;
            num := num * 10;
        };
        return num;
    };
    private func _decodeXdrUsd(_result : IC.CanisterHttpResponsePayload) : Nat {
        switch (Text.decodeUtf8(Blob.fromArray(_result.body))) {
            case (null) { assert(false); return 0;};
            case (?decoded) {
                return _textFloatToNat(decoded, 4);
            };
        };
    };
    private func _fetchXdrUsd() : async (){
        // var n1: Nat = 0;
        // var n2: Nat = 0;
        let host : Text = "www.xe.com";
        let request_headers = [
            { name = "Host"; value = host # ":443" },
            { name = "User-Agent"; value = "icoracle_canister" },
        ];
        let request : IC.CanisterHttpRequestArgs = {
            url = "https://www.xe.com/currencyconverter/convert/?Amount=1&From=XDR&To=USD";
            max_response_bytes = ?Nat64.fromNat(MAX_RESPONSE_BYTES);
            headers = request_headers;
            body = null;
            method = #get;
            transform = ?(#function(_xe_transform));
        };
        //try {
            Cycles.add(3_000_000_000);
            let ic : IC.Self = actor ("aaaaa-aa");
            let response = await ic.http_request(request);
            // n1 := response.body.size();
            // n2 := response.status;
            let result = _decodeXdrUsd(response);
            let sid: Nat = 0; // XDR-USD
            let provider = Principal.fromActor(this);
            var req : RequestLog = {
                request = { value = result; timestamp = Int.abs(Time.now() / 1000000000); };
                provider = provider;
                time = _now();
                signature = null;
            };
            ignore _setData(provider, sid, req);
        // } catch (err) {
        //     Debug.print(Error.message(err));
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
    public query(msg) func anon_getSeries(_sid: SeriesId, _page: ?Nat): async {data:[(Timestamp, Nat)]; decimals:Nat}{
        assert(_onlyAnon(msg.caller));
        var info: SeriesInfo = _getSeriesInfo(_sid);
        if (info.heartbeat == 0){
            return {data = []; decimals = info.decimals};
        };
        let page = Option.get(_page, 1);
        let periodSeconds = info.heartbeat * 500;
        return {data = _getSeries(_sid, page, periodSeconds); decimals = info.decimals};
    };
    public query(msg) func anon_get(_sid: SeriesId, _tsSeconds: ?Timestamp): async ?{data:(Timestamp, Nat); decimals:Nat}{
        assert(_onlyAnon(msg.caller));
        var info: SeriesInfo = _getSeriesInfo(_sid);
        let ts = Option.get(_tsSeconds, _now());
        switch(_getDataItem(_sid, ts)){
            case(?(res)){ return ?{data = res; decimals = info.decimals}; };
            case(_){ return null; };
        };
    };
    public query(msg) func anon_latest() : async [{name: Text; sid: SeriesId; decimals: Nat; data:(Timestamp, Nat)}]{
        assert(_onlyAnon(msg.caller));
        var res: [{name: Text; sid: SeriesId; decimals: Nat; data:(Timestamp, Nat)}] = [];
        for ((sid, info) in Trie.iter(seriesInfo)){
            switch(_getDataItem(sid, _now())){
                case(?(v)){ res := Tools.arrayAppend(res, [{name=info.0.name; sid=sid; decimals=info.0.decimals; data=v}]) };
                case(_){};
            };
        };
        return res;
    };
    public shared(msg) func getSeries(_sid: SeriesId, _page: ?Nat): async {data:[(Timestamp, Nat)]; decimals:Nat}{
        var info: SeriesInfo = _getSeriesInfo(_sid);
        if (info.heartbeat == 0){
            return {data = []; decimals = info.decimals};
        };
        _chargeFee(msg.caller, 2);
        let page = Option.get(_page, 1);
        let periodSeconds = info.heartbeat * 500; // page size = 500
        return {data = _getSeries(_sid, page, periodSeconds); decimals = info.decimals};
    };
    public shared(msg) func get(_sid: SeriesId, _tsSeconds: ?Timestamp): async ?{data:(Timestamp, Nat); decimals:Nat}{
        var info: SeriesInfo = _getSeriesInfo(_sid);
        let ts = Option.get(_tsSeconds, _now());
        switch(_getDataItem(_sid, ts)){
            case(?(res)){ 
                _chargeFee(msg.caller, 1);
                return ?{data = res; decimals = info.decimals}; 
            };
            case(_){ return null; };
        };
    };
    public shared(msg) func latest() : async [DataResponse]{
        var res: [{name: Text; sid: SeriesId; decimals: Nat; data:(Timestamp, Nat)}] = [];
        for ((sid, info) in Trie.iter(seriesInfo)){
            switch(_getDataItem(sid, _now())){
                case(?(v)){ 
                    _chargeFee(msg.caller, 2);
                    res := Tools.arrayAppend(res, [{name=info.0.name; sid=sid; decimals=info.0.decimals; data=v}]) 
                };
                case(_){};
            };
        };
        return res;
    };
    public shared(msg) func volatility(_sid: SeriesId, _period: Nat): async VolatilityResponse{
        var info: SeriesInfo = _getSeriesInfo(_sid);
        if (info.heartbeat == 0){
            assert(false);
        };
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
    public query func getLog(_sid: SeriesId, _tsSeconds: ?Timestamp): async ?Log{
        let ts = Option.get(_tsSeconds, _now());
        var info: SeriesInfo = _getSeriesInfo(_sid);
        if (info.heartbeat == 0){
            assert(false);
        };
        let pid = ts / info.heartbeat;
        return _getLog(_sid, pid);
    };
    // request '(0, record{value=12760; timestamp=1665414220;}, null)'
    public shared(msg) func request(_sid: SeriesId, _data: DataItem, signature: ?Blob) : async (confirmed: Bool){
        assert(_onlyProvider(msg.caller, _sid));
        let provider = _getProvider(msg.caller);
        let req : RequestLog = {
            request = _data;
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
    public shared(msg) func debug_fetchXdrUsd() : async (){
        assert(_onlyOwner(msg.caller));
        await _fetchXdrUsd();
    };
    public shared(msg) func debug_requestIcpXdr() : async (){
        assert(_onlyOwner(msg.caller));
        await _requestIcpXdr();
    };
    

    // Governance

    // Manage 
    public shared(msg) func setFee(_fee: Nat) : async (){
        fee := _fee;
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
                providers := List.push((provider.0, Tools.arrayAppend(provider.1, [_sid]), provider.2), providers); 
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
                providers := List.push((provider.0, provider.1, Tools.arrayAppend(provider.2, [_agent])), providers); 
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
    public shared(msg) func setDexSupport(_dex: Text, _router: Principal) : async (){
        assert(_onlyOwner(msg.caller));
        dexs := Trie.put(dexs, keyt(_dex), Text.equal, _router).0;
    };
    public shared(msg) func setSeriesInfo(_info: SeriesInfo): async SeriesId{
        let sid = index;
        index += 1;
        seriesInfo := Trie.put(seriesInfo, keyn(sid), Nat.equal, (_info, _now())).0;
        return sid;
    };
    public shared(msg) func updateSeriesInfo(_sid: SeriesId, _info: SeriesInfo): async Bool{
        seriesInfo := Trie.put(seriesInfo, keyn(_sid), Nat.equal, (_info, _getSeriesCreationTime(_sid))).0;
        return true;
    };

    // // 0: xdr/usd  permyriad
    // seriesInfo := Trie.put(seriesInfo, keyn(0), Nat.equal, ({
    //     name = "imf:1h:xdr/usd";  // gov: dex: mkt: imf:   tick: 1min: 5min: 10min: 1h: 1d:
    //     decimals = 4; 
    //     heartbeat = 3600; // seconds
    //     conMaxDevRate = 5; // ‱ permyriad
    //     conMinRequired = 1;
    //     conDuration = 7 * 24 * 3600;
    //     cacheDuration = 2 * 366 * 24 * 3600;
    // }, _now())).0;
    // // 1: icp/xdr  permyriad
    // seriesInfo := Trie.put(seriesInfo, keyn(1), Nat.equal, ({
    //     name = "gov:10min:icp/xdr";
    //     decimals = 4; 
    //     heartbeat = 600; // seconds
    //     conMaxDevRate = 10; // ‱ permyriad
    //     conMinRequired = 1; // from nns data
    //     conDuration = 24 * 3600;
    //     cacheDuration = 2 * 366 * 24 * 3600;
    // }, _now())).0;
    // // 2: icp/usd  permyriad
    // seriesInfo := Trie.put(seriesInfo, keyn(2), Nat.equal, ({
    //     name = "gov:10min:icp/usd";
    //     decimals = 4; 
    //     heartbeat = 600; // seconds
    //     conMaxDevRate = 10; // ‱ permyriad
    //     conMinRequired = 1; // from nns data
    //     conDuration = 24 * 3600;
    //     cacheDuration = 2 * 366 * 24 * 3600;
    // }, _now())).0;

    // DRC207 ICMonitor
    /// DRC207 support
    public func drc207() : async DRC207.DRC207Support{
        return {
            monitorable_by_self = true;
            monitorable_by_blackhole = { allowed = false; canister_id = ?Principal.fromText("7hdtw-jqaaa-aaaak-aaccq-cai"); };
            cycles_receivable = true;
            timer = { enable = false; interval_seconds = null; }; 
        };
    };
    /// canister_status
    public func canister_status() : async DRC207.canister_status {
        let ic : DRC207.IC = actor("aaaaa-aa");
        await ic.canister_status({ canister_id = Principal.fromActor(this) });
    };
    /// receive cycles
    public func wallet_receive(): async (){
        let amout = Cycles.available();
        let accepted = Cycles.accept(amout);
    };
    /// timer tick
    // public func timer_tick(): async (){
    //     let f = _requestIcpXdr();
    // };

    private stable var LastUpdatedIcpXdr: Time.Time = 0;
    private func _heartbeat_fetchIcpXdr() : async (){
        if (Time.now() >= LastUpdatedIcpXdr + 3600000000000){ // 3600s
            LastUpdatedIcpXdr := Time.now();
            await _requestIcpXdr();
        };
    };
    system func heartbeat() : async () {
        await _heartbeat_fetchIcpXdr();
    };

};