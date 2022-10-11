// jncgo-2iaaa-aaaan-qatba-cai
module {
  public type Address = Text;
  public type CanisterView = { id : Text; name : Text; cycle : Nat };
  public type NatResult = { #ok : Nat; #err : Text };
  public type ResponseResult = { #ok : [CanisterView]; #err : Text };
  public type Self = actor {
    addAdmin : shared Text -> async Bool;
    addPoolAdmin : shared Text -> async Bool;
    createSwapPoolCanister : shared (
        Address,
        Address,
        Text,
        Address,
        Text,
        Nat,
        Nat,
        Text,
      ) -> async Principal;
    cycleAvailable : shared () -> async NatResult;
    cycleBalance : shared query () -> async NatResult;
    getAdminList : shared query () -> async [Text];
    getCanisters : shared query () -> async ResponseResult;
    getPoolAdminList : shared query () -> async [Text];
    getStatus : shared Principal -> async {
        settings : { controllers : [Principal] };
      };
    getSwapFeeHolderCanisterId : shared query () -> async Text;
    removeAdmin : shared Text -> async Bool;
    resetController : shared () -> async ();
    setSwapFeeHolderCanisterId : shared Text -> ();
    updateController : shared () -> async ();
  }
}