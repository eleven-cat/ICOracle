/**
 * Module     : KLines.mo
 * Author     : ICLighthouse Team
 * Stability  : Experimental
 * Description: KLines for Dex.
 * Refers     : https://github.com/iclighthouse/
 */
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Array "mo:base/Array";
import Time "mo:base/Time";
import Hash "mo:base/Hash";
import List "mo:base/List";
import Trie "mo:base/Trie";
import Deque "mo:base/Deque";
import Buffer "mo:base/Buffer";
import Blob "mo:base/Blob";
import Binary "Binary";
import Nat64 "mo:base/Nat64";

module {
    public type Timestamp = Nat; // seconds
    public let NumberCachedBars: Nat = 1440;
    public type KInterval = Nat; // seconds
    // price = token1_amount * _UNIT_SIZE / token0_amount;  vol += token0_amount;
    public type KBar = {kid: Nat; open: Nat; high: Nat; low: Nat; close: Nat; vol: Nat; updatedTs: Timestamp}; // kid = ts_seconds / KInterval
    public type KLines = Trie.Trie<KInterval, Deque.Deque<KBar>>;

    private func _now() : Timestamp{
        return Int.abs(Time.now() / 1000000000);
    };
    // replace Hash.hash (Warning: Incompatible)
    private func natHash(n : Nat) : Hash.Hash{
      return Blob.hash(Blob.fromArray(Binary.BigEndian.fromNat64(Nat64.fromIntWrap(n))));
    };
    private func keyn(t: Nat) : Trie.Key<Nat> { return { key = t; hash = natHash(t) }; };
    public func arrayAppend<T>(a: [T], b: [T]) : [T]{
        let buffer = Buffer.Buffer<T>(1);
        for (t in a.vals()){
            buffer.add(t);
        };
        for (t in b.vals()){
            buffer.add(t);
        };
        return buffer.toArray();
    };

    /// KLine: create
    public func create() : KLines{
        return Trie.empty(); 
    };
    /// KLine: put
    public func put(_kl: KLines, _ki: KInterval, _price: Nat, _vol: Nat): KLines{
        let kid = _now() / _ki;
        var kl = _kl;
        switch(Trie.get(kl, keyn(_ki), Nat.equal)){
            case(?(kline)){
                var klineData = kline;
                switch(Deque.popFront(klineData)){
                    case(?(kbar, klineTemp)){
                        if (kid > kbar.kid){ // new kbar
                            klineData := Deque.pushFront(klineData, {kid = kid; open = _price; high = _price; low = _price; close = _price; vol = _vol; updatedTs = _now()});
                        }else if (kid == kbar.kid){ // update
                            klineData := Deque.pushFront(klineTemp, {kid = kid; open = kbar.open; high = Nat.max(kbar.high, _price); low = Nat.min(kbar.low, _price); close = _price; vol = kbar.vol + _vol; updatedTs = _now()});
                        }else{
                            // History bar cannot be modified.
                        };
                    };
                    case(_){ // new kbar
                        klineData := Deque.pushFront(klineData, {kid = kid; open = _price; high = _price; low = _price; close = _price; vol = _vol; updatedTs = _now()});
                    };
                };
                if (List.size(klineData.0) + List.size(klineData.1) > NumberCachedBars){
                    switch(Deque.popBack(klineData)){
                        case(?(klineNew, item)){ klineData := klineNew; };
                        case(_){};
                    };
                };
                kl := Trie.put(kl, keyn(_ki), Nat.equal, klineData).0;
            };
            case(_){ // new kbar
                var klineData: Deque.Deque<KBar> = Deque.empty();
                klineData := Deque.pushFront(klineData, {kid = kid; open = _price; high = _price; low = _price; close = _price; vol = _vol; updatedTs = _now()});
                kl := Trie.put(kl, keyn(_ki), Nat.equal, klineData).0;
            };
        };
        return kl;
    };
    /// KLine: putBatch
    public func putBatch(_kl: KLines, _data: [(Nat, Nat)]) : KLines {
        var kl = _kl;
        for ((price, quantity) in _data.vals()){
            kl := put(kl, 60, price, quantity); // 1min
            kl := put(kl, 60*5, price, quantity); // 5mins
            kl := put(kl, 3600, price, quantity); // 1h
            kl := put(kl, 3600*24, price, quantity); // 1d
            kl := put(kl, 3600*24*7, price, quantity); // 1w
        };
        return kl;
    };
    /// KLine: get
    public func get(_kl: KLines, _ki: KInterval) : [KBar]{
        switch(Trie.get(_kl, keyn(_ki), Nat.equal)){
            case(?(kline)){
                return arrayAppend(List.toArray(kline.0), List.toArray(List.reverse(kline.1)));
            };
            case(_){ return []; };
        };
    };

};