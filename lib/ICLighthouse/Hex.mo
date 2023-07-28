import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Char "mo:base/Char";
import Hash "mo:base/Hash";
import Iter "mo:base/Iter";
import Nat8 "mo:base/Nat8";
import Result "mo:base/Result";
import Buffer "mo:base/Buffer";

module {
    private let base : Nat8   = 16;
    private let hex  : [Char] = [
        '0', '1', '2', '3', 
        '4', '5', '6', '7', 
        '8', '9', 'a', 'b', 
        'c', 'd', 'e', 'f',
    ];

    private func toLower(c : Char) : Char {
        switch (c) {
            case ('A') { 'a' };
            case ('B') { 'b' };
            case ('C') { 'c' };
            case ('D') { 'd' };
            case ('E') { 'e' };
            case ('F') { 'f' };
            case (_)   { c;  };
        };
    };

    public type Hex = Text;

    public func arrayAppend<T>(a: [T], b: [T]) : [T]{
        let buffer = Buffer.Buffer<T>(1);
        for (t in a.vals()){
            buffer.add(t);
        };
        for (t in b.vals()){
            buffer.add(t);
        };
        return Buffer.toArray(buffer);
    };

    // Checks whether two hex strings are equal.
    public func equal(a : Hex, b : Hex) : Bool {
        if (a.size() != b.size()) return false;
        let bcs = b.chars();
        for (ac in a.chars()) {
            let a = toLower(ac);
            let bc = bcs.next();
            switch (bc) {
                case (null) { return false; };
                case (? bc) {
                    let b = toLower(bc);
                    if (a != b) return false;
                };
            };
        };
        bcs.next() == null;
    };

    // Hashes the given hex text.
    // NOTE: assumes the text is valid hex: [0-9a-fA-F].
    public func hash(h : Hex) : Hash.Hash {
        switch (decode(h)) {
            case (#err(_)) { assert(false); 0 };
            case (#ok(r)) { Blob.hash(Blob.fromArray(r)); };
        };
    };

    // Checks whether the given hex text is valid hex.
    public func valid(h : Hex) : Bool {
        for (c in h.chars()) {
            for (i in hex.keys()) {
                let h = hex[i];
                if (h != c and h != toLower(c)) {
                    return false;  
                };
            };
        };
        true;
    };

    // Converts a byte to its corresponding hexidecimal format.
    public func encodeByte(n : Nat8) : Hex {
        let c0 = hex[Nat8.toNat(n / base)];
        let c1 = hex[Nat8.toNat(n % base)];
        Char.toText(c0) # Char.toText(c1);
    };

    // Converts an array of bytes to their corresponding hexidecimal format.
    public func encode(ns : [Nat8]) : Hex {
        Array.foldRight<Nat8, Hex>(
            ns, 
            "", 
            func(n : Nat8, acc : Hex) : Hex {
                encodeByte(n) # acc;
            },
        );
    };

    // Converts the given hexadecimal character to its corresponding binary format.
    // NOTE: a hexadecimal char is just an 4-bit natural number.
    public func decodeChar(c : Char) : Result.Result<Nat8, Text> {
        for (i in hex.keys()) {
            let h = hex[i];
            if (h == c or h == toLower(c)) {
                return #ok(Nat8.fromNat(i));
            }
        };
        #err("unexpected character: " # Char.toText(c));
    };

    // Converts the given hexidecimal text to its corresponding binary format.
    public func decode(t : Hex) : Result.Result<[Nat8], Text> {
        var cs = Iter.toArray(t.chars());
        if (cs.size() % 2 != 0) {
            cs := arrayAppend(['0'], cs);
        };
        let ns = Array.init<Nat8>(cs.size() / 2, 0);
        for (i in Iter.range(0, ns.size() - 1)) {
            let j : Nat = i * 2;
            switch (decodeChar(cs[j])) {
                case (#err(e)) { return #err(e); };
                case (#ok(x0)) {
                    switch (decodeChar(cs[j+1])) {
                        case (#err(e)) { return #err(e); };
                        case (#ok(x1)) {
                            ns[i] := x0 * base + x1;
                        };
                    };
                };
            };
        };
        #ok(Array.freeze(ns));
    };

    public func decode2(t : Hex) : ?[Nat8]{
        switch(decode(t)){
            case (#ok(v)) ?v;
            case (#err(e)) null;
        }
    };
};
