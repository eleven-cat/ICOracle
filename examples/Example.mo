import ICOracle "../lib/ICOracle";
import Float "mo:base/Float";
import Int64 "mo:base/Int64";
import Nat64 "mo:base/Nat64";

actor class Example() = this {

    private func natToFloat(_n: Nat) : Float{
        return Float.fromInt64(Int64.fromNat64(Nat64.fromNat(_n)));
    };
    
    public shared func icp_usd() : async ?Float{
        let feed: ICOracle.Self = actor("pncff-zqaaa-aaaai-qnp3a-cai");
        switch(await feed.get(2, null)){
            case(?(result)){
                return ?(natToFloat(result.data.1) / natToFloat(10 ** result.decimals));
            };
            case(_){ return null };
        };

    };
};