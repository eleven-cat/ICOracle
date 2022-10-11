/**
 * Module     : DRC204.mo
 * Author     : ICLighthouse Team
 * Stability  : Experimental
 * Description: Adds dex info to the token.
 * Refers     : https://github.com/iclighthouse/
 */
import Principal "mo:base/Principal";

module {
    public type DexName = Text;
    public type TokenStd = { #icp; #cycles; #drc20; #dip20; #dft; #other: Text; }; // #cycles token principal = CF canister
    public type TokenSymbol = Text;
    public type TokenInfo = (Principal, TokenSymbol, TokenStd);
    public type SwapCanister = Principal;
    public type PairRequest = {
        token0: TokenInfo; 
        token1: TokenInfo; 
        dexName: DexName; 
    };
    public type SwapPair = {
        token0: TokenInfo; 
        token1: TokenInfo; 
        dexName: DexName; 
        canisterId: SwapCanister;
        feeRate: Float; 
    };
    public type ICDex = actor {
        create : shared (_token: ?Principal) -> async (canister: SwapCanister);
    };
    public type ICSwap = actor {
        create : shared (_pair: PairRequest) -> async (canister: SwapCanister, initialized: Bool);
        getPairsByToken : shared query (_token: Principal, _dexName: ?DexName) -> async [(SwapCanister, (SwapPair, Nat))];
    };
    public let icdexDex: Text = "ltyfs-qiaaa-aaaak-aan3a-cai";
    public let router: Text = "j4d4d-pqaaa-aaaak-aanxq-cai";
    public func icdex_create() : async Principal{
        let icdex: ICDex = actor(icdexDex);
        return await icdex.create(null);
    };
    public func getPairs(_token: Principal) : async [(Principal, (SwapPair, Nat))]{
        let routerActor: ICSwap = actor(router);
        return await routerActor.getPairsByToken(_token, null);
    };
};