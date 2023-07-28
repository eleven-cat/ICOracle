/**
 * Module     : DRC20.mo (ICTokens version)
 * Author     : ICLighthouse Team
 * License    : Apache License 2.0
 * Stability  : Experimental
 * Github     : https://github.com/iclighthouse/DRC_standards/
 */

import Prim "mo:⛔";
import Trie "mo:base/Trie";
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Option "mo:base/Option";
import Blob "mo:base/Blob";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Int "mo:base/Int";
import Int32 "mo:base/Int32";
import Iter "mo:base/Iter";
import List "mo:base/List";
import Time "mo:base/Time";
import Deque "mo:base/Deque";
import Order "mo:base/Order";
import Cycles "mo:base/ExperimentalCycles";
import CyclesWallet "./sys/CyclesWallet";
import Types "./lib/DRC20";
import AID "./lib/AID";
import Hex "./lib/Hex";
import Binary "./lib/Binary";
import SHA224 "./lib/SHA224";
import DRC202 "./lib/DRC202";
import ICPubSub "./lib/ICPubSub";
import DIP20 "./lib/DIP20";
import ICRC1 "./lib/ICRC1";
import DRC204 "./lib/DRC204";
import DRC207 "./lib/DRC207";

//record { totalSupply=45000000000000000; decimals=8; fee=10000000; name=opt "ICOracle Token"; symbol=opt "OT"; metadata=null; founder=null;} 
shared(installMsg) actor class DRC20(initArgs: Types.InitArgs) = this {
    /*
    * Types 
    */
    type Metadata = Types.Metadata;
    type Gas = Types.Gas;
    type Address = Types.Address; //Text
    type AccountId = Types.AccountId; //Blob
    type Txid = Types.Txid;  //Blob
    type TxnResult = Types.TxnResult;
    type ExecuteType = Types.ExecuteType;
    type Operation = Types.Operation;
    type Transaction = Types.Transaction;
    type TxnRecord = Types.TxnRecord;
    type Callback = Types.Callback;
    type MsgType = Types.MsgType;
    type Subscription = Types.Subscription;
    type Allowance = Types.Allowance;
    type TxnQueryRequest =Types.TxnQueryRequest;
    type TxnQueryResponse =Types.TxnQueryResponse;
    type CoinSeconds = Types.CoinSeconds;
    type From = Address;
    type To = Address;
    type Spender = Address;
    type Decider = Address;
    type Amount = Nat;
    type Sa = [Nat8];
    type Nonce = Nat;
    type Data = Blob;
    type Timeout = Nat32;
    type Config = Types.Config;

    /*
    * Config 
    */
    private stable var FEE_TO: AccountId = AID.blackhole(); 
    private stable var NonceStartBase: Nat = 10000000;
    private stable var NonceMode: Nat = 0; // Nonce mode is turned on when there is not enough storage space or when the nonce value of a single user exceeds `NonceStartBase`.
    private stable var AllowanceLimit: Nat = 50;
    private let MAX_MEMORY: Nat = 23*1024*1024*1024; // 23G

    /* 
    * State Variables 
    */
    private var standard_: Text = "drc20; icrc1; icrc2; dip20; ictokens"; 
    private stable var owner: Principal = installMsg.caller;  // @deprecated
    private stable var name_: Text = Option.get(initArgs.name, "");
    private stable var symbol_: Text = Option.get(initArgs.symbol, "");
    private stable let decimals_: Nat8 = initArgs.decimals;
    private stable var totalSupply_: Nat = initArgs.totalSupply;
    private stable var maxSupply_ : ?Nat = ?initArgs.totalSupply;
    private stable var totalCoinSeconds: CoinSeconds = {coinSeconds = 0; updateTime = Time.now()};
    private stable var fee_: Nat = initArgs.fee;
    private stable var metadata_: [Metadata] = Option.get(initArgs.metadata, []);
    private stable var index: Nat = 0;
    private stable var balances: Trie.Trie<AccountId, Nat> = Trie.empty();
    private stable var coinSeconds: Trie.Trie<AccountId, CoinSeconds> = Trie.empty();
    private stable var nonces: Trie.Trie<AccountId, Nat> = Trie.empty();
    private stable var allowances: Trie.Trie2D<AccountId, AccountId, Nat> = Trie.empty(); // Limit 50 records per account
    // private stable var cyclesBalances: Trie.Trie<AccountId, Nat> = Trie.empty();
    // Set EN_DEBUG=false in the production environment.
    private var drc202 = DRC202.DRC202({EN_DEBUG = false; MAX_CACHE_TIME = 3 * 30 * 24 * 3600 * 1000000000; MAX_CACHE_NUMBER_PER = 100; MAX_STORAGE_TRIES = 2; }, standard_);
    private stable var drc202_lastStorageTime : Time.Time = 0;
    private var pubsub = ICPubSub.ICPubSub<MsgType>({ MAX_PUBLICATION_TRIES = 2 }, func (t1:MsgType, t2:MsgType): Bool{ t1 == t2 });
    private stable var icps_lastPublishTime : Time.Time = 0;
    private stable var top100_: [(AccountId, Nat)] = [];
    private stable var top100Threshold: Nat = 0;
    private stable var firstTime: Trie.Trie<AccountId, Time.Time> = Trie.empty();
    private stable var balancesSnapshot: [(Trie.Trie<AccountId, Nat>, Time.Time)] = [];

    // public query func testTrieValid() : async [Bool]{ /*config*/
    //     return [
    //         Trie.isValid(balances, true),
    //         Trie.isValid(coinSeconds, true),
    //         Trie.isValid(nonces, true),
    //         Trie.isValid(allowances, true),
    //         Trie.isValid(firstTime, true),
    //         Trie.isValid(pubsub.getData().subscriptions, true),
    //         Trie.isValid(drc202.getData().txnRecords, true),
    //         Trie.isValid(drc202.getData().lastTxns_, true),
    //         Trie.isValid(drc202.getData().lockedTxns_, true),
    //     ];
    // };

    /* 
    * OT
    */
    private stable var minters: [Principal] = []; // [owner]  //ot
    private func _onlyMiner(_caller: Principal) : Bool { //ot
        return Option.isSome(Array.find(minters, func (t: Principal): Bool{ t == _caller }));
    };
    
    /* 
    * For storage saving mode
    */
    private stable var dropedAccounts: Trie.Trie<Blob, Bool> = Trie.empty(); // @deprecated
    private stable var droppedAccounts: Trie.Trie<Blob, Bool> = Trie.empty(); 
    private func _checkNonceMode(_upgrade: Bool) : (){
        if (NonceMode == 0 and (_upgrade or Prim.rts_memory_size() > MAX_MEMORY)){
            NonceMode := 1;
            if (drc202.getConfig().MAX_CACHE_TIME > 30 * 24 * 3600 * 1000000000){
                ignore drc202.config({ // Records cache for 30 days
                    EN_DEBUG = null;
                    MAX_CACHE_TIME = ?(30 * 24 * 3600 * 1000000000);
                    MAX_CACHE_NUMBER_PER = null;
                    MAX_STORAGE_TRIES = null;
                });
            };
            totalCoinSeconds := { coinSeconds = 0; updateTime = 0; };
            coinSeconds := Trie.empty(); // Disable the CoinSeconds function
            nonces := Trie.empty(); // Clearing nonces
            droppedAccounts := Trie.empty();  // Clearing droppedAccounts
            firstTime := Trie.empty();
        }else if (NonceMode > 0 and NonceMode < 200 and (_upgrade or Prim.rts_memory_size() > MAX_MEMORY)){
            NonceMode += 1;
            nonces := Trie.empty();
            droppedAccounts := Trie.empty(); 
            firstTime := Trie.empty();
        };
    };
    private func _checkAllowanceLimit(_a: AccountId) : Bool{
        switch(Trie.get(allowances, keyb(_a), Blob.equal)){ 
            case(?(allowTrie)){ return Trie.size(allowTrie) < AllowanceLimit; };
            case(_){ return true; };
        };
    };
    private func _getShortAccountId(_a: AccountId) : Blob{
        return Blob.fromArray(AID.slice(Blob.toArray(_a), 0, ?15));
    };
    private func _inDroppedAccount(_a: AccountId) : Bool{
        switch(Trie.get(droppedAccounts, keyb(_getShortAccountId(_a)), Blob.equal)){ 
            case(?(bool)){ return bool; };
            case(_){ return false; };
        };
    };
    private func _dropAccount(_a: AccountId) : Bool{ // (*)
        let minValue = fee_;
        if (_getBalance(_a) > minValue or (_getNonce(_a) == 0 and _getBalance(_a) == 0)){
            return false;
        };
        droppedAccounts := Trie.put(droppedAccounts, keyb(_getShortAccountId(_a)), Blob.equal, true).0;
        //balances
        balances := Trie.remove(balances, keyb(_a), Blob.equal).0;
        //coinSeconds
        coinSeconds := Trie.remove(coinSeconds, keyb(_a), Blob.equal).0;
        //nonces
        nonces := Trie.remove(nonces, keyb(_a), Blob.equal).0;
        //firstTime
        firstTime := Trie.remove(firstTime, keyb(_a), Blob.equal).0;
        //allowances
        allowances := Trie.remove(allowances, keyb(_a), Blob.equal).0;
        allowanceExpirations := Trie.remove(allowanceExpirations, keyb(_a), Blob.equal).0;
        return true;
    };

    /* 
    * Local Functions
    */
    private func _onlyOwner(_caller: Principal) : Bool { 
        return Prim.isController(_caller);
    };  // assert(_onlyOwner(msg.caller));
    private func keyb(t: Blob) : Trie.Key<Blob> { return { key = t; hash = Blob.hash(t) }; };
    private func _getAccountId(_address: Address): AccountId{
        switch (AID.accountHexToAccountBlob(_address)){
            case(?(a)){
                return a;
            };
            case(_){
                var p = Principal.fromText(_address);
                var a = AID.principalToAccountBlob(p, null);
                return a;
            };
        };
    }; 
    private func _getAccountIdFromPrincipal(_p: Principal, _sa: ?[Nat8]): AccountId{
        var a = AID.principalToAccountBlob(_p, _sa);
        return a;
    }; 
    private stable let founder_: AccountId = _getAccountId(Option.get(initArgs.founder, Principal.toText(installMsg.caller)));
    private func _getTxid(_caller: AccountId): Txid{ 
        var _nonce: Nat = _getNonce(_caller);
        return drc202.generateTxid(Principal.fromActor(this), _caller, _nonce);
    };
    private func _getBalance(_a: AccountId): Nat{
        switch(Trie.get(balances, keyb(_a), Blob.equal)){
            case(?(balance)){
                return balance;
            };
            case(_){
                return 0;
            };
        };
    };
    private func _setBalance(_a: AccountId, _v: Nat): (){
        let originalValue = _getBalance(_a);
        // CoinSeconds
        let now = Time.now();
        if (NonceMode == 0){
            let coinSecondsItem = Option.get(Trie.get(coinSeconds, keyb(_a), Blob.equal), {coinSeconds = 0; updateTime = now });
            let newCoinSeconds = coinSecondsItem.coinSeconds + originalValue * (Int.abs(now - coinSecondsItem.updateTime) / 1000000000);
            coinSeconds := Trie.put(coinSeconds, keyb(_a), Blob.equal, {coinSeconds = newCoinSeconds; updateTime = now}).0;
        };
        if(_v == 0){
            balances := Trie.remove(balances, keyb(_a), Blob.equal).0;
        } else {
            balances := Trie.put(balances, keyb(_a), Blob.equal, _v).0;
            if (_v < fee_ / 2){
                balances := Trie.remove(balances, keyb(_a), Blob.equal).0;
            };
        };
        _pushTop100(_a, _getBalance(_a));
        if (NonceMode == 0){
            _putFirstTime(_a);
        };
    };
    private func _getNonce(_a: AccountId): Nat{
        switch(Trie.get(nonces, keyb(_a), Blob.equal)){
            case(?(nonce)){
                return nonce;
            };
            case(_){
                return NonceStartBase * NonceMode;
            };
        };
    };
    private func _addNonce(_a: AccountId): (){
        var n = _getNonce(_a);
        nonces := Trie.put(nonces, keyb(_a), Blob.equal, n+1).0;
        index += 1;
        if (n+1 >= Nat.sub(NonceStartBase * (NonceMode + 1), 1)){
            _checkNonceMode(true);
        };
    };
    private func _getAllowances(_a: AccountId): [Allowance]{
        switch(Trie.get(allowances, keyb(_a), Blob.equal)){ 
            case(?(allowTrie)){
                var a = Iter.map(Trie.iter(allowTrie), func (entry: (AccountId, Nat)): Allowance{
                    return { spender = entry.0; remaining = entry.1; };
                });
                return Iter.toArray(a);
            };
            case(_){
                return [];
            };
        };
    };
    private func _getAllowance(_a: AccountId, _s: AccountId): Nat{
        let expiresAt = _getAllowanceExpiration(_a, _s);
        if (expiresAt > 0 and Time.now() > expiresAt){
            _setAllowance(_a, _s, 0);
            _setAllowanceExpiration(_a, _s, 0);
            return 0;
        };
        switch(Trie.get(allowances, keyb(_a), Blob.equal)){
            case(?(allowTrie)){
                switch(Trie.get(allowTrie, keyb(_s), Blob.equal)){
                    case(?(v)){
                        return v;
                    };
                    case(_){
                        return 0;
                    };
                };
            };
            case(_){
                return 0;
            };
        };
    };
    private func _setAllowance(_a: AccountId, _s: AccountId, _v: Nat): (){
        if (_v > 0){
            allowances := Trie.put2D(allowances, keyb(_a), Blob.equal, keyb(_s), Blob.equal, _v);
        }else{
            allowances := Trie.remove2D(allowances, keyb(_a), Blob.equal, keyb(_s), Blob.equal).0;
        };
    };
    // private func _getCyclesBalances(_a: AccountId) : Nat{
    //     switch(Trie.get(cyclesBalances, keyb(_a), Blob.equal)){
    //         case(?(balance)){ return balance; };
    //         case(_){ return 0; };
    //     };
    // };
    // private func _setCyclesBalances(_a: AccountId, _v: Nat) : (){
    //     if(_v == 0){
    //         cyclesBalances := Trie.remove(cyclesBalances, keyb(_a), Blob.equal).0;
    //     } else {
    //         switch (gas_){
    //             case(#cycles(fee)){
    //                 if (_v < fee/2){
    //                     cyclesBalances := Trie.remove(cyclesBalances, keyb(_a), Blob.equal).0;
    //                 } else{
    //                     cyclesBalances := Trie.put(cyclesBalances, keyb(_a), Blob.equal, _v).0;
    //                 };
    //             };
    //             case(_){
    //                 cyclesBalances := Trie.put(cyclesBalances, keyb(_a), Blob.equal, _v).0;
    //             };
    //         }
    //     };
    // };
    private func _checkFee(_caller: AccountId, _percent: Nat, _amount: Nat): Bool{
        if(fee_ > 0) {
            let fee = fee_ * _percent / 100;
            return _getBalance(_caller) >= fee + _amount;
        };
        return true;
    };
    private func _chargeFee(_caller: AccountId, _percent: Nat): Bool{
        if(fee_ > 0) {
            let fee = fee_ * _percent / 100;
            if (_getBalance(_caller) >= fee){
                ignore _send(_caller, FEE_TO, fee, false);
                return true;
            } else {
                return false;
            };
        };
        return true;
    };
    private func _send(_from: AccountId, _to: AccountId, _value: Nat, _isCheck: Bool): Bool{
        var balance_from = _getBalance(_from);
        if (balance_from >= _value){
            if (not(_isCheck)) { 
                balance_from -= _value;
                _setBalance(_from, balance_from);
                var balance_to = _getBalance(_to);
                balance_to += _value;
                _setBalance(_to, balance_to);
            };
            return true;
        } else {
            return false;
        };
    };
    private func _mint(_to: AccountId, _value: Nat): Bool{
        var balance_to = _getBalance(_to);
        balance_to += _value;
        _setBalance(_to, balance_to);
        if (NonceMode == 0){
            totalCoinSeconds := {
                coinSeconds = totalCoinSeconds.coinSeconds + totalSupply_ * (Int.abs(Time.now() - totalCoinSeconds.updateTime) / 1000000000); 
                updateTime = Time.now();
            };
        };
        totalSupply_ += _value;
        return true;
    };
    private func _burn(_from: AccountId, _value: Nat, _isCheck: Bool): Bool{
        var balance_from = _getBalance(_from);
        if (balance_from >= _value){
            if (not(_isCheck)) { 
                balance_from -= _value;
                _setBalance(_from, balance_from);
                if (NonceMode == 0){
                    totalCoinSeconds := {
                        coinSeconds = totalCoinSeconds.coinSeconds + totalSupply_ * (Int.abs(Time.now() - totalCoinSeconds.updateTime) / 1000000000); 
                        updateTime = Time.now();
                    };
                };
                totalSupply_ -= _value;
            };
            return true;
        } else {
            return false;
        };
    };
    private func _lock(_from: AccountId, _value: Nat, _isCheck: Bool): Bool{
        var balance_from = _getBalance(_from);
        if (balance_from >= _value){
            if (not(_isCheck)) { 
                balance_from -= _value;
                _setBalance(_from, balance_from);
            };
            return true;
        } else {
            return false;
        };
    };
    private func _execute(_from: AccountId, _to: AccountId, _value: Nat, _fallback: Nat): Bool{
        var balance_from = _getBalance(_from) + _fallback;
        _setBalance(_from, balance_from);
        var balance_to = _getBalance(_to) + _value;
        _setBalance(_to, balance_to);
        return true;
    };
    // Do not update state variables before calling _transfer
    private func _transfer(_msgCaller: Principal, _sa: ?[Nat8], _from: AccountId, _to: AccountId, _value: Nat, _nonce: ?Nat, _data: ?Blob, 
    _operation: Operation, _isAllowance: Bool): (result: TxnResult) {
        _checkNonceMode(false);
        var callerPrincipal = _msgCaller;
        let caller = _getAccountIdFromPrincipal(_msgCaller, _sa);
        let txid = _getTxid(caller);
        let from = _from;
        let to = _to;
        let value = _value; 
        var gas: Gas = #token(fee_);
        var allowed: Nat = 0; // *
        var spendValue = _value; // *
        if (_isAllowance){
            allowed := _getAllowance(from, caller);
        };
        let data = Option.get(_data, Blob.fromArray([]));
        if (_inDroppedAccount(from) or _inDroppedAccount(to)){
            return #err({ code=#UndefinedError; message="This account has been dropped"; });
        };
        if (data.size() > 2048){
            return #err({ code=#UndefinedError; message="The length of _data must be less than 2 KB"; });
        };
        if (Option.isSome(_nonce) and _getNonce(caller) != Option.get(_nonce,0)){
            return #err({ code=#NonceError; message="Wrong nonce! The nonce value should be "#Nat.toText(_getNonce(caller)); });
        };
        switch(_operation){
            case(#transfer(operation)){
                switch(operation.action){
                    case(#mint){ gas := #noFee;};
                    case(_){};
                };
            };
            case(#executeTransfer(operation)){ gas := #noFee; };
            case(_){};
        };
        var txn: TxnRecord = {
            txid = txid;
            msgCaller = null; // If you want to maintain anonymity, you can hide the principal of the caller
            caller = caller;
            timestamp = Time.now();
            index = index;
            nonce = _getNonce(caller);
            gas = gas;
            transaction = {
                from = from;
                to = to;
                value = value; 
                operation = _operation;
                data = _data;
            };
        };
        // check and operate
        switch(_operation){
            case(#transfer(operation)){
                switch(operation.action){
                    case(#send){
                        if (not(_send(from, to, value, true))){
                            return #err({ code=#InsufficientBalance; message="Insufficient Balance"; });
                        } else if (_isAllowance and allowed < spendValue){
                            return #err({ code=#InsufficientAllowance; message="Insufficient Allowance"; });
                        };
                        ignore _send(from, to, value, false);
                        var as: [AccountId] = [from, to];
                        if (_isAllowance and spendValue > 0){
                            _setAllowance(from, caller, allowed - spendValue);
                            as := AID.arrayAppend(as, [caller]);
                        };
                        drc202.pushLastTxn(as, txid); 
                        pubsub.put(as, #onTransfer, txn);
                    };
                    case(#mint){
                        ignore _mint(to, value);
                        var as: [AccountId] = [to];
                        drc202.pushLastTxn(as, txid); 
                        as := AID.arrayAppend(as, [caller]);
                        pubsub.put(as, #onTransfer, txn);
                    };
                    case(#burn){
                        if (not(_burn(from, value, true))){
                            return #err({ code=#InsufficientBalance; message="Insufficient Balance"; });
                        } else if (_isAllowance and allowed < spendValue){
                            return #err({ code=#InsufficientAllowance; message="Insufficient Allowance"; });
                        };
                        ignore _burn(from, value, false);
                        var as: [AccountId] = [from];
                        if (_isAllowance and spendValue > 0){
                            _setAllowance(from, caller, allowed - spendValue);
                            as := AID.arrayAppend(as, [caller]);
                        };
                        drc202.pushLastTxn(as, txid); 
                        pubsub.put(as, #onTransfer, txn);
                    };
                };
            };
            case(#lockTransfer(operation)){
                spendValue := operation.locked;
                if (not(_lock(from, operation.locked, true))){
                    return #err({ code=#InsufficientBalance; message="Insufficient Balance"; });
                } else if (_isAllowance and allowed < spendValue){
                    return #err({ code=#InsufficientAllowance; message="Insufficient Allowance"; });
                };
                ignore _lock(from, operation.locked, false);
                var as: [AccountId] = [from, to, operation.decider];
                if (_isAllowance and spendValue > 0){
                    _setAllowance(from, caller, allowed - spendValue);
                    as := AID.arrayAppend(as, [caller]);
                };
                drc202.pushLastTxn(as, txid);
                pubsub.put(as, #onLock, txn);
                drc202.appendLockedTxn(from, txid);
            };
            case(#executeTransfer(operation)){
                spendValue := 0;
                ignore _execute(from, to, value, operation.fallback);
                var as: [AccountId] = [from, to, caller];
                drc202.pushLastTxn(as, txid);
                pubsub.put(as, #onExecute, txn);
                drc202.dropLockedTxn(from, operation.lockedTxid);
            };
            case(#approve(operation)){
                spendValue := 0;
                _setAllowance(from, to, operation.allowance); 
                var as: [AccountId] = [from, to];
                drc202.pushLastTxn(as, txid);
                pubsub.put(as, #onApprove, txn);
                //callerPrincipal := Principal.fromText("2vxsx-fae");  // [4] Anonymous principal
            };
        };
        // insert record
        drc202.put(txn); 
        // update nonce
        _addNonce(caller); 
        return #ok(txid);
    };

    //--------------
    // private func __cyclesReceive(__caller: Principal, _account: ?Address) : (balance: Nat){
    //     let amount = Cycles.available(); 
    //     assert(amount >= 100000000);
    //     var account = FEE_TO; //_getAccountIdFromPrincipal(Principal.fromActor(this));
    //     switch(_account){
    //         case(?(a)){
    //             account := _getAccountId(a);
    //             switch (gas_){
    //                 case(#token(fee)){ assert(false); };
    //                 case(_){};
    //             };
    //         };
    //         case(_){};
    //     };
    //     let accepted = Cycles.accept(amount); 
    //     let balance = _getCyclesBalances(account);
    //     _setCyclesBalances(account, balance + accepted);
    //     return balance + accepted;
    // };
    private func __getCoinSeconds(_owner: ?Address) : (totalCoinSeconds: CoinSeconds, accountCoinSeconds: ?CoinSeconds){
        if (NonceMode > 0){
            return ({ coinSeconds = 0; updateTime = 0; }, null);
        };
        let now = Time.now();
        let newTotalCoinSeconds = { coinSeconds = totalCoinSeconds.coinSeconds + totalSupply_ * (Int.abs(now - totalCoinSeconds.updateTime) / 1000000000); updateTime = now; };
        switch(_owner){
            case(?(owner)){ 
                let account = _getAccountId(owner);
                switch(Trie.get(coinSeconds, keyb(account), Blob.equal)){
                    case(?(coinSecondsItem)){
                        let newAccountCoinSeconds = { coinSeconds = coinSecondsItem.coinSeconds + _getBalance(account) * (Int.abs(now - coinSecondsItem.updateTime) / 1000000000); updateTime = now; };
                        return (newTotalCoinSeconds, ?newAccountCoinSeconds);
                    };
                    case(_){ return (newTotalCoinSeconds, null); };
                };
            };
            case(_){ return (newTotalCoinSeconds, null); };
        };
    };
    private func __transferFrom(__caller: Principal, _from: AccountId, _to: AccountId, _value: Amount, _nonce: ?Nonce, _sa: ?Sa, _data: ?Data, _isSpender: Bool) : 
    (result: TxnResult) {
        let from = _from;
        let to = _to;
        let operation: Operation = #transfer({ action = #send; });
        // check fee
        if(not(_checkFee(from, 100, _value))){
            return #err({ code=#InsufficientBalance; message="Insufficient Balance"; });
        };
        // transfer
        let res = _transfer(__caller, _sa, from, to, _value, _nonce, _data, operation, _isSpender);
        // charge fee
        switch(res){
            case(#ok(v)){ ignore _chargeFee(from, 100); return res; };
            case(#err(v)){ return res; };
        };
    };
    private func __lockTransferFrom(__caller: Principal, _from: AccountId, _to: AccountId, _value: Amount, 
    _timeout: Timeout, _decider: ?Decider, _nonce: ?Nonce, _sa: ?Sa, _data: ?Data, _isSpender: Bool) : (result: TxnResult) {
        if (_timeout > 64000000){
            return #err({ code=#UndefinedError; message="Parameter _timeout should not be greater than 64,000,000 seconds."; });
        };
        var decider: AccountId = _getAccountIdFromPrincipal(__caller, _sa);
        switch(_decider){
            case(?(v)){ decider := _getAccountId(v); };
            case(_){};
        };
        let operation: Operation = #lockTransfer({ 
            locked = _value;  // be locked for the amount
            expiration = Time.now() + Int32.toInt(Int32.fromNat32(_timeout)) * 1000000000;  
            decider = decider;
        });
        let from = _from;
        let to = _to;
        // check fee
        if(not(_checkFee(from, 100, _value))){
            return #err({ code=#InsufficientBalance; message="Insufficient Balance"; });
        };
        // transfer
        let res = _transfer(__caller, _sa, from, to, 0, _nonce, _data, operation, _isSpender);
        // charge fee
        switch(res){
            case(#ok(v)){ ignore _chargeFee(from, 100); return res; };
            case(#err(v)){ return res; };
        };
    };
    private func __executeTransfer(__caller: Principal, _txid: Txid, _executeType: ExecuteType, _to: ?To, _nonce: ?Nonce, _sa: ?Sa, _data: ?Data) : (result: TxnResult) {
        let txid = _txid;
        let caller = _getAccountIdFromPrincipal(__caller, _sa);
        // check fee
        // if(not(_checkFee(caller, 100, 0))){
        //     return #err({ code=#InsufficientGas; message="Insufficient Gas"; });
        // };
        switch(drc202.get(txid)){
            case(?(txn)){
                let from = txn.transaction.from;
                var to = txn.transaction.to;
                switch(txn.transaction.operation){
                    case(#lockTransfer(v)){
                        if (not(drc202.inLockedTxns(txid, from))){
                            return #err({ code=#DuplicateExecutedTransfer; message="The transaction has already been executed"; });
                        };
                        let locked = v.locked;
                        let expiration = v.expiration;
                        let decider = v.decider;
                        var fallback: Nat = 0;
                        switch(_to){
                            case(?(newTo)){ 
                                if (caller == decider and decider == to){
                                    to := _getAccountId(newTo); 
                                } else {
                                    return #err({ code=#UndefinedError; message="No permission to change the address `to`"; });
                                };
                            };
                            case(_){};
                        };
                        switch(_executeType){
                            case(#fallback){
                                if (not( caller == decider or (Time.now() > expiration and caller == from) )) {
                                    return #err({ code=#UndefinedError; message="No Permission"; });
                                };
                                fallback := locked;
                            };
                            case(#sendAll){
                                if (Time.now() > expiration){
                                    return #err({ code=#LockedTransferExpired; message="Locked Transfer Expired"; });
                                };
                                if (caller != decider){
                                    return #err({ code=#UndefinedError; message="No Permission"; });
                                };
                                fallback := 0;
                            };
                            case(#send(v)){
                                if (Time.now() > expiration){
                                    return #err({ code=#LockedTransferExpired; message="Locked Transfer Expired"; });
                                };
                                if (caller != decider){
                                    return #err({ code=#UndefinedError; message="No Permission"; });
                                };
                                fallback := locked - v;
                            };
                        };
                        var value: Nat = 0;
                        if (locked > fallback){
                            value := locked - fallback;
                        };
                        let operation: Operation = #executeTransfer({ 
                            lockedTxid = txid;  
                            fallback = fallback;
                        });
                        let res = _transfer(__caller, _sa, from, to, value, _nonce, _data, operation, false);
                        // charge fee
                        // switch(res){
                        //     case(#ok(v)){ ignore _chargeFee(caller, 100); };
                        //     case(#err(v)){ };
                        // };
                        return res;
                    };
                    case(_){
                        return #err({ code=#NoLockedTransfer; message="No Locked Transfer"; });
                    };
                };
            };
            case(_){
                return #err({ code=#NoLockedTransfer; message="No Locked Transfer"; });
            };
        };
    };
    private func __approve(__caller: Principal, _spender: Spender, _value: Amount, _nonce: ?Nonce, _sa: ?Sa, _data: ?Data) : (result: TxnResult){
        let from = _getAccountIdFromPrincipal(__caller, _sa);
        let to = _getAccountId(_spender);
        let operation: Operation = #approve({ allowance = _value; });
        if (not(_checkAllowanceLimit(from))){
            return #err({ code=#UndefinedError; message="The number of allowance records exceeds the limit"; });
        };
        // check fee
        if(not(_checkFee(from, 100, 0))){
            return #err({ code=#InsufficientGas; message="Insufficient Gas"; });
        };
        // transfer
        let res = _transfer(__caller, _sa, from, to, 0, _nonce, _data, operation, false);
        // charge fee
        switch(res){
            case(#ok(v)){ ignore _chargeFee(from, 100); return res; };
            case(#err(v)){ return res; };
        };
    };
    private func __subscribe(__caller: Principal, _callback: Callback, _msgTypes: [MsgType], _sa: ?Sa) : Bool{
        let caller = _getAccountIdFromPrincipal(__caller, _sa);
        assert(_chargeFee(caller, 100));
        let sub: Subscription = {
            callback = _callback;
            msgTypes = _msgTypes;
        };
        pubsub.sub(caller, sub);
        return true;
    };
    private func __txnQuery(_request: TxnQueryRequest) : (response: TxnQueryResponse){
        switch(_request){
            case(#txnCountGlobal){
                return #txnCountGlobal(index);
            };
            case(#txnCount(args)){
                var account = _getAccountId(args.owner);
                return #txnCount(_getNonce(account));
            };
            case(#getTxn(args)){
                return #getTxn(drc202.get(args.txid));
            };
            case(#lastTxidsGlobal){
                return #lastTxidsGlobal(drc202.getLastTxns(null));
            };
            case(#lastTxids(args)){
                return #lastTxids(drc202.getLastTxns(?_getAccountId(args.owner)));
            };
            case(#lockedTxns(args)){
                var txids = drc202.getLockedTxns(_getAccountId(args.owner));
                var lockedBalance: Nat = 0;
                var txns: [TxnRecord] = [];
                for (txid in txids.vals()){
                    switch(drc202.get(txid)){
                        case(?(record)){
                            switch(record.transaction.operation){
                                case(#lockTransfer(v)){
                                    lockedBalance += v.locked;
                                };
                                case(_){};
                            };
                            txns := AID.arrayAppend(txns, [record]);
                        };
                        case(_){};
                    };
                };
                return #lockedTxns({ lockedBalance = lockedBalance; txns = txns; });   
            };
            case(#getEvents(args)){
                switch(args.owner) {
                    case(null){
                        var i: Nat = 0;
                        return #getEvents(Array.chain(drc202.getLastTxns(null), func (value:Txid): [TxnRecord]{
                            if (i < drc202.getConfig().MAX_CACHE_NUMBER_PER){
                                i += 1;
                                switch(drc202.get(value)){
                                    case(?(r)){ return [r]; };
                                    case(_){ return []; };
                                };
                            }else{ return []; };
                        }));
                    };
                    case(?(address)){
                        return #getEvents(Array.chain(drc202.getLastTxns(?_getAccountId(address)), func (value:Txid): [TxnRecord]{
                            switch(drc202.get(value)){
                                case(?(r)){ return [r]; };
                                case(_){ return []; };
                            };
                        }));
                    };
                };
            };
        };
    };

    // push and sort top100
    private func _pushTop100(_a: AccountId, _balance: Nat) : (){ 
        var top100 = Array.filter(top100_, func (v:(AccountId,Nat)): Bool { v.0 != _a });
        if (_balance >= top100Threshold){
            top100 := AID.arrayAppend(top100, [(_a, _balance)]);
            top100 := Array.sort(top100, func (v1:(AccountId,Nat), v2:(AccountId,Nat)):Order.Order {
                //reverse order
                if (v1.1 > v2.1){
                    return #less;
                }else if (v1.1 == v2.1){
                    return #equal;
                }else{
                    return #greater;
                };
            });
            if (top100.size() > 200 and top100[200].1 > top100Threshold){
                top100Threshold := top100[200].1;
            };
        };
        top100_ := AID.slice(top100, 0, ?199);
    };
    // put first time
    private func _putFirstTime(_a: AccountId) : (){
        switch(Trie.get(firstTime, keyb(_a), Blob.equal)){
            case(?(ft)){};
            case(_){
                firstTime := Trie.put(firstTime, keyb(_a), Blob.equal, Time.now()).0;
            };
        };
    };
    // max supply
    private func _validateMaxSupply(_value: Nat) : Bool{
        switch(maxSupply_){
            case(?(supply)){ return totalSupply_ + _value <= supply; };
            case(_){ return true; };
        };
    };

    /* 
    * Shared Functions
    */

    /// Returns standard name.
    public query func standard() : async Text{
        return standard_;
    };

    // dip20 standard (main interface).
    private func _receipt(_result: TxnResult) : DIP20.TxReceipt{
        switch(_result){
            case(#ok(txid)){
                switch(drc202.get(txid)){
                    case(?(txn)){ return #Ok(txn.index) };
                    case(_){ return #Ok(0) };
                };
            };
            case(#err(err)){
                switch(err.code){
                    case(#InsufficientGas) { return #Err(#InsufficientBalance) };
                    case(#InsufficientAllowance) { return #Err(#InsufficientAllowance) };
                    case(#UndefinedError) { return #Err(#Other(err.message)) };
                    case(#InsufficientBalance) { return #Err(#InsufficientBalance) };
                    case(#NonceError) { return #Err(#Other(err.message)) };
                    case(#NoLockedTransfer) { return #Err(#Other(err.message)) };
                    case(#DuplicateExecutedTransfer) { return #Err(#Other(err.message)) };
                    case(#LockedTransferExpired) { return #Err(#Other(err.message)) };
                };
            };
        };
    };
    public shared(msg) func transfer(to: Principal, value: Nat) : async DIP20.TxReceipt {
        let _from = _getAccountIdFromPrincipal(msg.caller, null);
        let _to = _getAccountIdFromPrincipal(to, null);
        // dip20 does not support account-id, sub-account, nonce, attached data
        let res = __transferFrom(msg.caller, _from, _to, value, null, null, null, false);
        // publish
        if (pubsub.threads() == 0 or Time.now() > icps_lastPublishTime + 60*1000000000){
            icps_lastPublishTime := Time.now();
            ignore pubsub.pub();
        };
        // Store data to the DRC202 scalable bucket, requires a 20 second interval to initiate a batch store, and may be rejected if you store frequently.
        if (Time.now() > drc202_lastStorageTime + 20*1000000000) { 
            drc202_lastStorageTime := Time.now();
            ignore drc202.store(); 
        };
        return _receipt(res);
    };
    public shared(msg) func transferFrom(from: Principal, to: Principal, value: Nat) : async DIP20.TxReceipt {
        let _from = _getAccountIdFromPrincipal(from, null);
        let _to = _getAccountIdFromPrincipal(to, null);
        // dip20 does not support account-id, sub-account, nonce, attached data
        let res = __transferFrom(msg.caller, _from, _to, value, null, null, null, true);
        // publish
        if (pubsub.threads() == 0 or Time.now() > icps_lastPublishTime + 60*1000000000){
            icps_lastPublishTime := Time.now();
            ignore pubsub.pub();
        };
        // Store data to the DRC202 scalable bucket, requires a 20 second interval to initiate a batch store, and may be rejected if you store frequently.
        if (Time.now() > drc202_lastStorageTime + 20*1000000000) { 
            drc202_lastStorageTime := Time.now();
            ignore drc202.store(); 
        };
        return _receipt(res);
    };
    public shared(msg) func approve(spender: Principal, value: Nat) : async DIP20.TxReceipt {
        // dip20 does not support account-id, sub-account, nonce, attached data
        let res = __approve(msg.caller, Principal.toText(spender), value, null, null, null);
        // publish
        if (pubsub.threads() == 0 or Time.now() > icps_lastPublishTime + 60*1000000000){
            icps_lastPublishTime := Time.now();
            ignore pubsub.pub();
        };
        // Store data to the DRC202 scalable bucket, requires a 20 second interval to initiate a batch store, and may be rejected if you store frequently.
        if (Time.now() > drc202_lastStorageTime + 20*1000000000) { 
            drc202_lastStorageTime := Time.now();
            ignore drc202.store(); 
        };
        return _receipt(res);
    };
    private func _getLogo() : Text{
        for (meta in metadata_.vals()){
            if (meta.name == "logo" or meta.name == "Logo" or meta.name == "LOGO") { return meta.content; };
        };
        return "";
    };
    public query func logo() : async Text {
        return _getLogo();
    };
    public query func name() : async Text {
        return name_;
    };
    public query func symbol() : async Text {
        return symbol_;
    };
    public query func decimals() : async Nat8 {
        return decimals_;
    };
    public query func totalSupply() : async Nat {
        return totalSupply_;
    };
    public query func getTokenFee() : async Nat {
        return fee_;
    };
    public query func balanceOf(who: Principal) : async Nat {
        return _getBalance(_getAccountIdFromPrincipal(who, null));
    };
    public query func allowance(owner: Principal, spender: Principal) : async Nat {
        return _getAllowance(_getAccountIdFromPrincipal(owner, null), _getAccountIdFromPrincipal(spender, null));
    };
    public query func getMetadata() : async DIP20.Metadata {
        return {
            logo = _getLogo();
            name = name_;
            symbol = symbol_;
            decimals = decimals_;
            totalSupply = totalSupply_;
            owner = installMsg.caller; // No owner
            fee = fee_;
        };
    };
    public query func historySize() : async Nat {
        return index;
    };
    public query func getTokenInfo(): async DIP20.TokenInfo {
        return {
            metadata = {
                logo = _getLogo();
                name = name_;
                symbol = symbol_;
                decimals = decimals_;
                totalSupply = totalSupply_;
                owner = installMsg.caller;
                fee = fee_;
            };
            feeTo = Principal.fromText("aaaaa-aa"); // It indicates the blackhole address
            historySize = index;
            deployTime = 0; // No deployTime
            holderNumber = Trie.size(balances);
            cycles = Cycles.balance();
        };
    };


    // drc20 standard (Compatibility aliases).
    public query func drc20_name() : async Text{
        return name_;
    };
    public query func drc20_symbol() : async Text{
        return symbol_;
    };
    public query func drc20_decimals() : async Nat8{
        return decimals_;
    };
    public query func drc20_metadata() : async [Metadata]{
        return metadata_;
    };
    // public shared(msg) func drc20_cyclesReceive(_account: ?Address) : async (balance: Nat){
    //     return __cyclesReceive(msg.caller, _account);
    // };
    // public query func drc20_cyclesBalanceOf(_owner: Address) : async (balance: Nat){
    //     return _getCyclesBalances(_getAccountId(_owner));
    // };
    public query func drc20_gas() : async Gas{
        return #token(fee_);
    };
    public query func drc20_fee() : async Amount{
        return fee_;
    };
    public query func drc20_totalSupply() : async Amount{
        return totalSupply_;
    };
    public query func drc20_getCoinSeconds(_owner: ?Address) : async (totalCoinSeconds: CoinSeconds, accountCoinSeconds: ?CoinSeconds){
        return __getCoinSeconds(_owner);
    };
    public query func drc20_balanceOf(_owner: Address) : async (balance: Amount){
        return _getBalance(_getAccountId(_owner));
    };
    public shared(msg) func drc20_transfer(_to: To, _value: Amount, _nonce: ?Nonce, _sa: ?Sa, _data: ?Data) : async (result: TxnResult) {
        let res = __transferFrom(msg.caller, _getAccountIdFromPrincipal(msg.caller, _sa), _getAccountId(_to), _value, _nonce, _sa, _data, false);
        // publish
        if (pubsub.threads() == 0 or Time.now() > icps_lastPublishTime + 60*1000000000){
            icps_lastPublishTime := Time.now();
            ignore pubsub.pub();
        };
        // Store data to the DRC202 scalable bucket, requires a 20 second interval to initiate a batch store, and may be rejected if you store frequently.
        if (Time.now() > drc202_lastStorageTime + 20*1000000000) { 
            drc202_lastStorageTime := Time.now();
            ignore drc202.store(); 
        };
        return res;
    };
    public shared(msg) func drc20_transferBatch(_to: [To], _value: [Amount], _nonce: ?Nonce, _sa: ?Sa, _data: ?Data) : async (result: [TxnResult]) {
        assert(_to.size() == _value.size());
        var res : [TxnResult] = [];
        var i : Nat = 0;
        var nonce = _nonce;
        label send for (to in _to.vals()){
            if (i > 0) { nonce := null; };
            let r = __transferFrom(msg.caller, _getAccountIdFromPrincipal(msg.caller, _sa), _getAccountId(to), _value[i], nonce, _sa, _data, false);
            res := AID.arrayAppend(res, [r]);
            switch(r){
                case(#err(e)){
                    assert(false);
                };
                case(_){};
            };
            i += 1;
        };
        // publish
        if (pubsub.threads() == 0 or Time.now() > icps_lastPublishTime + 60*1000000000){
            icps_lastPublishTime := Time.now();
            ignore pubsub.pub();
        };
        // Store data to the DRC202 scalable bucket, requires a 20 second interval to initiate a batch store, and may be rejected if you store frequently.
        if (Time.now() > drc202_lastStorageTime + 20*1000000000) { 
            drc202_lastStorageTime := Time.now();
            ignore drc202.store(); 
        };
        return res;
    };
    public shared(msg) func drc20_transferFrom(_from: From, _to: To, _value: Amount, _nonce: ?Nonce, _sa: ?Sa, _data: ?Data) : 
    async (result: TxnResult) {
        let res = __transferFrom(msg.caller, _getAccountId(_from), _getAccountId(_to), _value, _nonce, _sa, _data, true);
        // publish
        if (pubsub.threads() == 0 or Time.now() > icps_lastPublishTime + 60*1000000000){
            icps_lastPublishTime := Time.now();
            ignore pubsub.pub();
        };
        // Store data to the DRC202 scalable bucket, requires a 20 second interval to initiate a batch store, and may be rejected if you store frequently.
        if (Time.now() > drc202_lastStorageTime + 20*1000000000) { 
            drc202_lastStorageTime := Time.now();
            ignore drc202.store(); 
        };
        return res;
    };
    public shared(msg) func drc20_lockTransfer(_to: To, _value: Amount, _timeout: Timeout, 
    _decider: ?Decider, _nonce: ?Nonce, _sa: ?Sa, _data: ?Data) : async (result: TxnResult) {
        let res = __lockTransferFrom(msg.caller, _getAccountIdFromPrincipal(msg.caller, _sa), _getAccountId(_to), _value, _timeout, _decider, _nonce, _sa, _data, false);
        // publish
        if (pubsub.threads() == 0 or Time.now() > icps_lastPublishTime + 60*1000000000){
            icps_lastPublishTime := Time.now();
            ignore pubsub.pub();
        };
        // Store data to the DRC202 scalable bucket, requires a 20 second interval to initiate a batch store, and may be rejected if you store frequently.
        if (Time.now() > drc202_lastStorageTime + 20*1000000000) { 
            drc202_lastStorageTime := Time.now();
            ignore drc202.store(); 
        };
        return res;
    };
    public shared(msg) func drc20_lockTransferFrom(_from: From, _to: To, _value: Amount, 
    _timeout: Timeout, _decider: ?Decider, _nonce: ?Nonce, _sa: ?Sa, _data: ?Data) : async (result: TxnResult) {
        let res = __lockTransferFrom(msg.caller, _getAccountId(_from), _getAccountId(_to), _value, _timeout, _decider, _nonce, _sa, _data, true);
        // publish
        if (pubsub.threads() == 0 or Time.now() > icps_lastPublishTime + 60*1000000000){
            icps_lastPublishTime := Time.now();
            ignore pubsub.pub();
        };
        // Store data to the DRC202 scalable bucket, requires a 20 second interval to initiate a batch store, and may be rejected if you store frequently.
        if (Time.now() > drc202_lastStorageTime + 20*1000000000) { 
            drc202_lastStorageTime := Time.now();
            ignore drc202.store(); 
        };
        return res;
    };
    public shared(msg) func drc20_executeTransfer(_txid: Txid, _executeType: ExecuteType, _to: ?To, _nonce: ?Nonce, _sa: ?Sa, _data: ?Data) : async (result: TxnResult) {
        let res = __executeTransfer(msg.caller, _txid, _executeType, _to, _nonce, _sa, _data);
        // publish
        if (pubsub.threads() == 0 or Time.now() > icps_lastPublishTime + 60*1000000000){
            icps_lastPublishTime := Time.now();
            ignore pubsub.pub();
        };
        // Store data to the DRC202 scalable bucket, requires a 20 second interval to initiate a batch store, and may be rejected if you store frequently.
        if (Time.now() > drc202_lastStorageTime + 20*1000000000) { 
            drc202_lastStorageTime := Time.now();
            ignore drc202.store(); 
        };
        return res;
    };
    public query func drc20_txnQuery(_request: TxnQueryRequest) : async (response: TxnQueryResponse){
        return __txnQuery(_request);
    };
    public shared func drc20_txnRecord(_txid: Txid) : async ?TxnRecord{
        switch(drc202.get(_txid)){
            case(?(txn)){ return ?txn; };
            case(_){
                return await drc202.get2(Principal.fromActor(this), _txid);
            };
        };
    };
    public shared(msg) func drc20_subscribe(_callback: Callback, _msgTypes: [MsgType], _sa: ?Sa) : async Bool{
        return __subscribe(msg.caller, _callback, _msgTypes, _sa);
    };
    public query func drc20_subscribed(_owner: Address) : async (result: ?Subscription){
        return pubsub.getSub(_getAccountId(_owner));
    };
    public shared(msg) func drc20_approve(_spender: Spender, _value: Amount, _nonce: ?Nonce, _sa: ?Sa, _data: ?Data) : async (result: TxnResult){
        let res = __approve(msg.caller, _spender, _value, _nonce, _sa, _data);
        // publish
        if (pubsub.threads() == 0 or Time.now() > icps_lastPublishTime + 60*1000000000){
            icps_lastPublishTime := Time.now();
            ignore pubsub.pub();
        };
        // Store data to the DRC202 scalable bucket, requires a 20 second interval to initiate a batch store, and may be rejected if you store frequently.
        if (Time.now() > drc202_lastStorageTime + 20*1000000000) { 
            drc202_lastStorageTime := Time.now();
            ignore drc202.store(); 
        };
        return res;
    };
    public query func drc20_allowance(_owner: Address, _spender: Spender) : async (remaining: Amount) {
        return _getAllowance(_getAccountId(_owner), _getAccountId(_spender));
    };
    public query func drc20_approvals(_owner: Address) : async (allowances: [Allowance]) {
        return _getAllowances(_getAccountId(_owner));
    };
    public shared(msg) func drc20_dropAccount(_sa: ?Sa) : async Bool{
        return _dropAccount(_getAccountIdFromPrincipal(msg.caller, _sa));
    };
    public query func drc20_holdersCount() : async (balances: Nat, nonces: Nat, droppedAccounts: Nat){
        return (Trie.size(balances), Trie.size(nonces), Trie.size(droppedAccounts));
    };

    // icrc1 standard (https://github.com/dfinity/ICRC-1)
    type Value = ICRC1.Value;
    type Subaccount = ICRC1.Subaccount;
    type Account = ICRC1.Account;
    type TransferArgs = ICRC1.TransferArgs;
    type TransferError = ICRC1.TransferError;
    private func _icrc1_get_account(_a: Account) : Blob{
        var sub: ?[Nat8] = null;
        switch(_a.subaccount){
            case(?(_sub)){ sub := ?(Blob.toArray(_sub)) };
            case(_){};
        };
        return _getAccountIdFromPrincipal(_a.owner, sub);
    };
    private func _icrc1_getFee() : Nat{
        return fee_;
    };
    private func _icrc1_receipt(_result: TxnResult, _a: AccountId) : { #Ok: Nat; #Err: TransferError; }{
        switch(_result){
            case(#ok(txid)){
                switch(drc202.get(txid)){
                    case(?(txn)){ return #Ok(txn.index) };
                    case(_){ return #Ok(0) };
                };
            };
            case(#err(err)){
                var fee = { expected_fee: Nat = fee_ };
                switch(err.code){
                    case(#InsufficientGas) { return #Err(#BadFee(fee)) };
                    case(#InsufficientAllowance) { return #Err(#GenericError({ error_code = 101; message = err.message })) };
                    case(#UndefinedError) { return #Err(#GenericError({ error_code = 999; message = err.message })) };
                    case(#InsufficientBalance) { return #Err(#InsufficientFunds({ balance = _getBalance(_a); })) };
                    case(#NonceError) { return #Err(#GenericError({ error_code = 102; message = err.message })) };
                    case(#NoLockedTransfer) { return #Err(#GenericError({ error_code = 103; message = err.message })) };
                    case(#DuplicateExecutedTransfer) { return #Err(#GenericError({ error_code = 104; message = err.message })) };
                    case(#LockedTransferExpired) { return #Err(#GenericError({ error_code = 105; message = err.message })) };
                };
            };
        };
    };

    private func _toSaNat8(_sa: ?Blob) : ?[Nat8]{
        switch(_sa){
            case(?(sa)){ return ?Blob.toArray(sa); };
            case(_){ return null; };
        }
    };
    private let TX_WINDOW: Int = 14400_000_000_000; // 4 hours
    private let PERMITTED_DRIFT: Int = 180_000_000_000; // 3 minutes
    private func _icrc1_idempotency(_created_at_time: ?Nat64, __caller: Principal, _from: AccountId, _to: AccountId, _value: Amount, _nonce: ?Nonce, _sa: ?Sa, _data: ?Data, _isSpender: Bool) : 
    { #Ok; #TransferErr: TransferError; #TransferFromErr: TransferFromError }{
        let caller = _getAccountIdFromPrincipal(__caller, _sa);
        switch(_created_at_time){
            case(?(created_at_time)){
                if (Nat64.toNat(created_at_time) + TX_WINDOW + PERMITTED_DRIFT < Time.now()){
                    if (_isSpender){ #TransferFromErr(#TooOld) } else { #TransferErr(#TooOld) };
                }else if (Nat64.toNat(created_at_time) > Time.now() + PERMITTED_DRIFT){
                    if (_isSpender){ #TransferFromErr(#CreatedInFuture({ ledger_time = Nat64.fromIntWrap(Time.now()) })) } 
                    else { #TransferErr(#CreatedInFuture({ ledger_time = Nat64.fromIntWrap(Time.now()) })) };
                }else{
                    let events = drc202.getEvents(?caller);
                    switch(Array.find(events, func (txn: TxnRecord): Bool{
                        txn.timestamp + PERMITTED_DRIFT >= Time.now() and txn.timestamp <= Time.now() + PERMITTED_DRIFT and 
                        txn.caller == caller and txn.transaction.from == _from and txn.transaction.to == _to and txn.transaction.value == _value and txn.transaction.data == _data
                    })){
                        case(?(txn)){
                            if (_isSpender){ #TransferFromErr(#Duplicate({ duplicate_of = txn.index })) } 
                            else { #TransferErr(#Duplicate({ duplicate_of = txn.index })) };
                        };
                        case(_){ return #Ok; };
                    };
                };
            };
            case(_){
                return #Ok;
            };
        };
    };
    public query func icrc1_supported_standards() : async [{ name : Text; url : Text }]{
        return [
            {name = "DIP20"; url = "https://github.com/Psychedelic/DIP20"},
            {name = "DRC20"; url = "https://github.com/iclighthouse/DRC_standards/blob/main/DRC20/DRC20.md"},
            {name = "ICRC-1"; url = "https://github.com/dfinity/ICRC-1"},
            {name = "ICRC-2"; url = "https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-2"}
        ];
    };
    public query func icrc1_minting_account() : async ?Account{
        return null; // {owner = installMsg.caller; subaccount = null;};
    };
    public query func icrc1_name() : async Text{
        return name_;
    };
    public query func icrc1_symbol() : async Text{
        return symbol_;
    };
    public query func icrc1_decimals() : async Nat8{
        return decimals_;
    };
    public query func icrc1_fee() : async Nat{
        return _icrc1_getFee();
    };
    public query func icrc1_metadata() : async [(Text, Value)]{
        let md1: [(Text, Value)] = [("icrc1:symbol", #Text(symbol_)), ("icrc1:name", #Text(name_)), ("icrc1:decimals", #Nat(Nat8.toNat(decimals_))), 
        ("icrc1:fee", #Nat(_icrc1_getFee())), ("icrc1:total_supply", #Nat(totalSupply_)), ("icrc1:max_memo_length", #Nat(2048))];
        var md2: [(Text, Value)] = Array.map<Metadata, (Text, Value)>(metadata_, func (item: Metadata) : (Text, Value) {
            if (item.name == "logo"){
                ("icrc1:"#item.name, #Text(item.content))
            }else{
                ("drc20:"#item.name, #Text(item.content))
            }
        });
        md2 := AID.arrayAppend(md2, [("drc20:height", #Nat(index))]);
        md2 := AID.arrayAppend(md2, [("drc20:holders", #Nat(Trie.size(balances)))]);
        md2 := AID.arrayAppend(md2, [("ictokens:maxSupply", #Nat(Option.get(maxSupply_, 0)))]);
        return AID.arrayAppend(md1, md2);
    };
    public query func icrc1_total_supply() : async Nat{
        return totalSupply_;
    };
    public query func icrc1_balance_of(_owner: Account) : async (balance: Nat){
        return _getBalance(_icrc1_get_account(_owner));
    };
    public shared(msg) func icrc1_transfer(_args: TransferArgs) : async ({ #Ok: Nat; #Err: TransferError; }) {
        switch(_args.fee){
            case(?(icrc1_fee)){
                if (icrc1_fee < fee_){ return #Err(#BadFee({ expected_fee = fee_ })) };
            };
            case(_){};
        };
        let from = _icrc1_get_account({ owner = msg.caller; subaccount = _args.from_subaccount; });
        let sub = _toSaNat8(_args.from_subaccount);
        let to = _icrc1_get_account(_args.to);
        let data = _args.memo;
        switch(_icrc1_idempotency(_args.created_at_time, msg.caller, from, to, _args.amount, null, sub, data, false)){
            case(#TransferErr(err)){ return #Err(err); };
            case(_){};
        };
        let res = __transferFrom(msg.caller, from, to, _args.amount, null, sub, data, false);
        // publish
        if (pubsub.threads() == 0 or Time.now() > icps_lastPublishTime + 60*1000000000){
            icps_lastPublishTime := Time.now();
            ignore pubsub.pub();
        };
        // Store data to the DRC202 scalable bucket, requires a 20 second interval to initiate a batch store, and may be rejected if you store frequently.
        if (Time.now() > drc202_lastStorageTime + 20*1000000000) { 
            drc202_lastStorageTime := Time.now();
            ignore drc202.store(); 
        };
        return _icrc1_receipt(res, from);
    };
    /*
    * ICRC-2
    */
    type ApproveArgs = ICRC1.ApproveArgs;
    type ApproveError = ICRC1.ApproveError;
    type TransferFromArgs = ICRC1.TransferFromArgs;
    type TransferFromError = ICRC1.TransferFromError;
    type AllowanceArgs = ICRC1.AllowanceArgs;
    private stable var allowanceExpirations: Trie.Trie2D<AccountId, AccountId, Time.Time> = Trie.empty(); 
    private func _getAllowanceExpiration(_a: AccountId, _s: AccountId): Time.Time{
        switch(Trie.get(allowanceExpirations, keyb(_a), Blob.equal)){
            case(?(allowTrie)){
                switch(Trie.get(allowTrie, keyb(_s), Blob.equal)){
                    case(?(v)){
                        return v;
                    };
                    case(_){
                        return 0;
                    };
                };
            };
            case(_){
                return 0;
            };
        };
    };
    private func _setAllowanceExpiration(_a: AccountId, _s: AccountId, _v: Time.Time): (){
        if (_v > 0){
            allowanceExpirations := Trie.put2D(allowanceExpirations, keyb(_a), Blob.equal, keyb(_s), Blob.equal, _v);
        }else{
            allowanceExpirations := Trie.remove2D(allowanceExpirations, keyb(_a), Blob.equal, keyb(_s), Blob.equal).0;
            switch(Trie.get(allowanceExpirations, keyb(_a), Blob.equal)){
                case(?(allowTrie)){
                    if (Trie.size(allowTrie) == 0){ allowanceExpirations := Trie.remove(allowanceExpirations, keyb(_a), Blob.equal).0; };
                };
                case(_){};
            };
        };
    };
    private func _icrc2_approve_receipt(_result: TxnResult, _a: AccountId) : { #Ok: Nat; #Err: ApproveError; }{
        switch(_result){
            case(#ok(txid)){
                switch(drc202.get(txid)){
                    case(?(txn)){ return #Ok(txn.index) };
                    case(_){ return #Ok(0) };
                };
            };
            case(#err(err)){
                var fee = { expected_fee: Nat = fee_ };
                switch(err.code){
                    case(#InsufficientGas) { return #Err(#BadFee(fee)) };
                    case(#InsufficientAllowance) { return #Err(#GenericError({ error_code = 101; message = err.message })) };
                    case(#UndefinedError) { return #Err(#GenericError({ error_code = 999; message = err.message })) };
                    case(#InsufficientBalance) { return #Err(#InsufficientFunds({ balance = _getBalance(_a); })) };
                    case(#NonceError) { return #Err(#GenericError({ error_code = 102; message = err.message })) };
                    case(#NoLockedTransfer) { return #Err(#GenericError({ error_code = 103; message = err.message })) };
                    case(#DuplicateExecutedTransfer) { return #Err(#GenericError({ error_code = 104; message = err.message })) };
                    case(#LockedTransferExpired) { return #Err(#GenericError({ error_code = 105; message = err.message })) };
                };
            };
        };
    };
    private func _icrc2_transfer_from_receipt(_result: TxnResult, _a: AccountId, _spender: AccountId) : { #Ok: Nat; #Err: TransferFromError; }{
        switch(_result){
            case(#ok(txid)){
                switch(drc202.get(txid)){
                    case(?(txn)){ return #Ok(txn.index) };
                    case(_){ return #Ok(0) };
                };
            };
            case(#err(err)){
                var fee = { expected_fee: Nat = fee_ };
                switch(err.code){
                    case(#InsufficientGas) { return #Err(#BadFee(fee)) };
                    case(#InsufficientAllowance) { return #Err(#InsufficientAllowance({ allowance = _getAllowance(_a, _spender)})) };
                    case(#UndefinedError) { return #Err(#GenericError({ error_code = 999; message = err.message })) };
                    case(#InsufficientBalance) { return #Err(#InsufficientFunds({ balance = _getBalance(_a); })) };
                    case(#NonceError) { return #Err(#GenericError({ error_code = 102; message = err.message })) };
                    case(#NoLockedTransfer) { return #Err(#GenericError({ error_code = 103; message = err.message })) };
                    case(#DuplicateExecutedTransfer) { return #Err(#GenericError({ error_code = 104; message = err.message })) };
                    case(#LockedTransferExpired) { return #Err(#GenericError({ error_code = 105; message = err.message })) };
                };
            };
        };
    };
    public shared(msg) func icrc2_approve(_args: ApproveArgs) : async { #Ok : Nat; #Err : ApproveError }{
        // arg `created_at_time` is invalid.
        switch(_args.fee){
            case(?(icrc1_fee)){
                if (icrc1_fee < fee_){ return #Err(#BadFee({ expected_fee = fee_ })) };
            };
            case(_){};
        };
        let spender = _icrc1_get_account(_args.spender);
        var value : Nat = _args.amount;
        // if (_args.amount > 0){
        //     value := Int.abs(_args.amount);
        // };
        let from = _icrc1_get_account({ owner = msg.caller; subaccount = _args.from_subaccount; });
        let sub = _toSaNat8(_args.from_subaccount);
        let data = _args.memo;
        switch(_args.expected_allowance){
            case(?(expectedAllowance)){
                let currentAllowance = _getAllowance(from, spender);
                if (expectedAllowance != currentAllowance){ return #Err(#AllowanceChanged({ current_allowance = currentAllowance })) };
            };
            case(_){};
        };
        let res = __approve(msg.caller, Hex.encode(Blob.toArray(spender)), value, null, sub, data);
        switch(res, _args.expires_at){
            case(#ok(txid), ?(expires_at)){
                _setAllowanceExpiration(from, spender, Nat64.toNat(expires_at));
            };
            case(_, _){};
        };
        // publish
        if (pubsub.threads() == 0 or Time.now() > icps_lastPublishTime + 60*1000000000){
            icps_lastPublishTime := Time.now();
            ignore pubsub.pub();
        };
        // Store data to the DRC202 scalable bucket, requires a 20 second interval to initiate a batch store, and may be rejected if you store frequently.
        if (Time.now() > drc202_lastStorageTime + 20*1000000000) { 
            drc202_lastStorageTime := Time.now();
            ignore drc202.store(); 
        };
        return _icrc2_approve_receipt(res, from);
    };
    public shared(msg) func icrc2_transfer_from(_args: TransferFromArgs) : async { #Ok : Nat; #Err : TransferFromError } {
        switch(_args.fee){
            case(?(icrc1_fee)){
                if (icrc1_fee < fee_){ return #Err(#BadFee({ expected_fee = fee_ })) };
            };
            case(_){};
        };
        let spender = _icrc1_get_account({ owner = msg.caller; subaccount = _args.spender_subaccount; });
        let from = _icrc1_get_account(_args.from);
        let to = _icrc1_get_account(_args.to);
        let value = _args.amount;
        let data = _args.memo;
        switch(_icrc1_idempotency(_args.created_at_time, msg.caller, from, to, value, null, null, data, true)){
            case(#TransferFromErr(err)){ return #Err(err); };
            case(_){};
        };
        let res = __transferFrom(msg.caller, from, to, value, null, null, data, true);
        // publish
        if (pubsub.threads() == 0 or Time.now() > icps_lastPublishTime + 60*1000000000){
            icps_lastPublishTime := Time.now();
            ignore pubsub.pub();
        };
        // Store data to the DRC202 scalable bucket, requires a 20 second interval to initiate a batch store, and may be rejected if you store frequently.
        if (Time.now() > drc202_lastStorageTime + 20*1000000000) { 
            drc202_lastStorageTime := Time.now();
            ignore drc202.store(); 
        };
        return _icrc2_transfer_from_receipt(res, from, spender);
    };
    public query func icrc2_allowance(_args: AllowanceArgs) : async { allowance : Nat; expires_at : ?Nat64 } {
        let owner = _icrc1_get_account(_args.account);
        let spender = _icrc1_get_account(_args.spender);
        let expiresAt = Int.abs(_getAllowanceExpiration(owner, spender));
        return { allowance = _getAllowance(owner, spender); expires_at = if (expiresAt > 0){ ?Nat64.fromNat(expiresAt) }else{ null } };
    };

    /* 
    * Owner's Management
    */
    // public query func ictokens_getOwner() : async Principal{  //ict
    //     return owner;
    // };
    // public shared(msg) func ictokens_changeOwner(_newOwner: Principal) : async Bool{  //ict
    //     assert(_onlyOwner(msg.caller));
    //     owner := _newOwner;
    //     return true;
    // };
    // config 
    public shared(msg) func ictokens_config(config: Config) : async Bool{ //ict
        assert(_onlyOwner(msg.caller));
        FEE_TO := _getAccountId(Option.get(config.feeTo, Hex.encode(Blob.toArray(FEE_TO)))); 
        return true;
    };
    public query func ictokens_getConfig() : async Config{ //ict
        return { //ict
            feeTo = ?Hex.encode(Blob.toArray(FEE_TO));
        };
    };
    public shared(msg) func ictokens_setMetadata(_metadata: [Metadata]) : async Bool{ //ict
        assert(_onlyOwner(msg.caller));
        metadata_ := _metadata;
        return true;
    };
    public shared(msg) func ictokens_setFee(_fee: Amount) : async Bool{ //ict
        assert(_onlyOwner(msg.caller));
        fee_ := _fee;
        return true;
    };

    /*
    * Extended functions
    */
    /// max supply
    public query func ictokens_maxSupply() : async ?Nat{
        return maxSupply_;
    };
    /// top100
    public query func ictokens_top100() : async [(Address, Nat)]{
        return Array.map<(AccountId, Nat), (Address, Nat)>(AID.slice(top100_, 0, ?99), func (item: (AccountId, Nat)): (Address, Nat){
            return (Hex.encode(Blob.toArray(item.0)), item.1);
        });
    };
    /// held first time 
    public query func ictokens_heldFirstTime(_owner: Address) : async ?Time.Time{
        let account = _getAccountId(_owner);
        return Trie.get(firstTime, keyb(account), Blob.equal);
    };
    /// Snapshot
    public shared(msg) func ictokens_snapshot(_threshold: Amount) : async Bool{  //ict
        assert(_onlyOwner(msg.caller));
        let balancesTrie = Trie.filter(balances, func (key:AccountId, value:Nat):Bool{ value >= _threshold });
        balancesSnapshot := AID.arrayAppend(balancesSnapshot, [(balancesTrie, Time.now())]);
        return true;
    };
    public shared(msg) func ictokens_clearSnapshot() : async Bool{  //ict
        assert(_onlyOwner(msg.caller));
        balancesSnapshot := [];
        return true;
    };
    // _snap=0,1,2...  _page=1,2,3...  page-size:200   
    public query func ictokens_getSnapshot(_snap: Nat, _page: Nat) : async (Time.Time, [(AccountId, Nat)], Bool){ 
        let (balances_,snapTime) = balancesSnapshot[_snap];
        let length = Trie.size(balances_);
        var isEnd = false;
        let from = Nat.sub(Nat.max(_page,1), 1) * 200;
        if (from+199 >= length){ isEnd := true; };
        let arr = AID.slice(Trie.toArray(balances_, func (k:AccountId, v:Nat):((AccountId, Nat)){ (k, v) }), from, ?(from+199));
        return (snapTime, arr, isEnd);
    };
    public query func ictokens_snapshotBalanceOf(_snap: Nat, _owner: Address) : async (Time.Time, ?Nat) {
        let (balances_,snapTime) = balancesSnapshot[_snap];
        let account = _getAccountId(_owner);
        return (snapTime, Trie.get(balances_, keyb(account), Blob.equal));
    };

    /*
    * OT
    */
    public shared(msg) func ictokens_addMinter(_minter: Principal) : async Bool{ //ot
        assert(_onlyOwner(msg.caller));
        minters := AID.arrayAppend(minters, [_minter]);
        return true;
    };
    public shared(msg) func ictokens_removeMinter(_minter: Principal) : async Bool{  //ot
        assert(_onlyOwner(msg.caller));
        minters := Array.filter(minters, func (t: Principal): Bool{ t != _minter });
        return true;
    };
    public query func ictokens_minters() : async [Principal]{  //ot
        return minters;
    };
    public shared(msg) func ictokens_mint(_to: Address, _value: Amount, _nonce: ?Nonce, _data: ?Data) : async (result: TxnResult) { //ot
        assert(_onlyMiner(msg.caller));
        assert(_validateMaxSupply(_value));
        let from = AID.blackhole();
        let to = _getAccountId(_to);
        let operation: Operation = #transfer({ action = #mint; });
        // transfer
        let res = _transfer(msg.caller, null, from, to, _value, _nonce, _data, operation, false);
        // publish
        if (pubsub.threads() == 0 or Time.now() > icps_lastPublishTime + 60*1000000000){
            icps_lastPublishTime := Time.now();
            ignore pubsub.pub();
        };
        // Store data to the DRC202 scalable bucket, requires a 20 second interval to initiate a batch store, and may be rejected if you store frequently.
        if (Time.now() > drc202_lastStorageTime + 20*1000000000) { 
            drc202_lastStorageTime := Time.now();
            ignore drc202.store(); 
        };
        return res;
    };
    public shared(msg) func ictokens_burn(_value: Amount, _nonce: ?Nonce, _sa: ?Sa, _data: ?Data) : async (result: TxnResult) { //ot
        let from = _getAccountIdFromPrincipal(msg.caller, _sa);
        let to = AID.blackhole();
        let operation: Operation = #transfer({ action = #burn; });
        // check
        let balance = _getBalance(from);
        var gasToken = fee_;
        assert(_value > gasToken or (_value > 0 and _value == balance));
        if(not(_checkFee(from, 0, _value))){
            return #err({ code=#InsufficientBalance; message="Insufficient Balance"; });
        };
        // transfer
        let res = _transfer(msg.caller, _sa, from, to, _value, _nonce, _data, operation, false);
        // publish
        if (pubsub.threads() == 0 or Time.now() > icps_lastPublishTime + 60*1000000000){
            icps_lastPublishTime := Time.now();
            ignore pubsub.pub();
        };
        // Store data to the DRC202 scalable bucket, requires a 20 second interval to initiate a batch store, and may be rejected if you store frequently.
        if (Time.now() > drc202_lastStorageTime + 20*1000000000) { 
            drc202_lastStorageTime := Time.now();
            ignore drc202.store(); 
        };
        return res;
    };

    // drc202
    public query func drc202_getConfig() : async DRC202.Setting{
        return drc202.getConfig();
    };
    public query func drc202_canisterId() : async Principal{
        return drc202.drc202CanisterId();
    };
    public shared(msg) func drc202_config(config: DRC202.Config) : async Bool{ 
        assert(_onlyOwner(msg.caller));
        return drc202.config(config);
    };
    /// returns events
    public query func drc202_events(_account: ?DRC202.Address) : async [DRC202.TxnRecord]{
        switch(_account){
            case(?(account)){ return drc202.getEvents(?_getAccountId(account)); };
            case(_){return drc202.getEvents(null);}
        };
    };
    /// returns txn record. It's an query method that will try to find txn record in token canister cache.
    public query func drc202_txn(_txid: DRC202.Txid) : async (txn: ?DRC202.TxnRecord){
        return drc202.get(_txid);
    };
    /// returns txn record. It's an update method that will try to find txn record in the DRC202 canister if the record does not exist in this canister.
    public shared func drc202_txn2(_txid: DRC202.Txid) : async (txn: ?DRC202.TxnRecord){
        switch(drc202.get(_txid)){
            case(?(txn)){ return ?txn; };
            case(_){
                return await drc202.get2(Principal.fromActor(this), _txid);
            };
        };
    };
    /// returns drc202 pool
    public query func drc202_pool() : async [(DRC202.Txid, Nat)]{
        return drc202.getPool();
    };

    // ICPubSub
    public query func icpubsub_getConfig() : async ICPubSub.Setting{
        return pubsub.getConfig();
    };
    public shared(msg) func icpubsub_config(config: ICPubSub.Config) : async Bool{ 
        assert(_onlyOwner(msg.caller));
        return pubsub.config(config);
    };

    // DRC204
    public shared(msg) func icdex_create() : async Principal{
        assert(_onlyOwner(msg.caller));
        let icdex_pair = await DRC204.icdex_create();
        return icdex_pair;
    };
    public shared func drc204_pairs() : async [(Principal, (DRC204.SwapPair, Nat))]{
        return await DRC204.getPairs(Principal.fromActor(this));
    };
    public query func drc204_router(): async Principal{
        return Principal.fromText(DRC204.router);
    };

    /* 
    * Genesis
    */
    private stable var genesisCreated: Bool = false;
    if (not(genesisCreated)){
        balances := Trie.put(balances, keyb(founder_), Blob.equal, totalSupply_).0;
        coinSeconds := Trie.put(coinSeconds, keyb(founder_), Blob.equal, {coinSeconds = 0; updateTime = Time.now()}).0;
        var txn: TxnRecord = {
            txid = Blob.fromArray([0:Nat8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]);
            msgCaller = ?installMsg.caller;
            caller = AID.principalToAccountBlob(installMsg.caller, null);
            timestamp = Time.now();
            index = index;
            nonce = 0;
            gas = #noFee;
            transaction = {
                from = AID.blackhole();
                to = founder_;
                value = totalSupply_; 
                operation = #transfer({ action = #mint; });
                data = null;
            };
        };
        index += 1;
        nonces := Trie.put(nonces, keyb(AID.principalToAccountBlob(installMsg.caller, null)), Blob.equal, 1).0;
        drc202.put(txn);
        drc202.pushLastTxn([founder_], txn.txid);
        genesisCreated := true;
    };

    // DRC207 ICMonitor
    /// DRC207 support
    public query func drc207() : async DRC207.DRC207Support{
        return {
            monitorable_by_self = false;
            monitorable_by_blackhole = { allowed = true; canister_id = ?Principal.fromText("7hdtw-jqaaa-aaaak-aaccq-cai"); };
            cycles_receivable = true;
            timer = { enable = false; interval_seconds = null; }; 
        };
    };
    /// canister_status
    // public func canister_status() : async DRC207.canister_status {
    //     let ic : DRC207.IC = actor("aaaaa-aa");
    //     await ic.canister_status({ canister_id = Principal.fromActor(this) });
    // };
    /// receive cycles
    public func wallet_receive(): async (){
        let amout = Cycles.available();
        let accepted = Cycles.accept(amout);
    };
    /// timer tick
    // public func timer_tick(): async (){
    //     //
    // };

    // upgrade (Compatible with the previous version)
    private stable var __drc202Data: [DRC202.DataTemp] = [];
    private stable var __drc202DataNew: ?DRC202.DataTemp = null;
    private stable var __pubsubData: [ICPubSub.DataTemp<MsgType>] = [];
    private stable var __pubsubDataNew: ?ICPubSub.DataTemp<MsgType> = null;
    system func preupgrade() {
        __drc202DataNew := ?drc202.getData();
        __pubsubDataNew := ?pubsub.getData();
    };
    system func postupgrade() {
        switch(__drc202DataNew){
            case(?(data)){
                drc202.setData(data);
                __drc202Data := [];
                __drc202DataNew := null;
            };
            case(_){
                if (__drc202Data.size() > 0){
                    drc202.setData(__drc202Data[0]);
                    __drc202Data := [];
                };
            };
        };
        switch(__pubsubDataNew){
            case(?(data)){
                pubsub.setData(data);
                __pubsubData := [];
                __pubsubDataNew := null;
            };
            case(_){
                if (__pubsubData.size() > 0){
                    pubsub.setData(__pubsubData[0]);
                    __pubsubData := [];
                };
            };
        };
        if (Trie.size(droppedAccounts) == 0 and NonceMode == 0){
            droppedAccounts := dropedAccounts;
        };
    };

};