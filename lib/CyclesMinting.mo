// canister-id: rkp4c-7iaaa-aaaaa-aaaca-cai
module {
  public type CyclesResponse = {
    #Refunded : (Text, ?Nat64);
    #CanisterCreated : Principal;
    #ToppedUp;
  };
  public type ICPTs = { e8s : Nat64 };
  public type IcpXdrConversionRate = {
    xdr_permyriad_per_icp : Nat64; 
    timestamp_seconds : Nat64;
  };
  public type IcpXdrConversionRateCertifiedResponse = {
    certificate : [Nat8];
    data : IcpXdrConversionRate;
    hash_tree : [Nat8];
  };
  public type Result = { #Ok : CyclesResponse; #Err : Text };
  public type SetAuthorizedSubnetworkListArgs = {
    who : ?Principal;
    subnets : [Principal];
  };
  public type TransactionNotification = {
    to : Principal;
    to_subaccount : ?[Nat8];
    from : Principal;
    memo : Nat64;
    from_subaccount : ?[Nat8];
    amount : ICPTs;
    block_height : Nat64;
  };
  public type Self = actor {
    get_average_icp_xdr_conversion_rate : shared query () -> async IcpXdrConversionRateCertifiedResponse;
    get_icp_xdr_conversion_rate : shared query () -> async IcpXdrConversionRateCertifiedResponse;
    set_authorized_subnetwork_list : shared SetAuthorizedSubnetworkListArgs -> async ();
    transaction_notification : shared TransactionNotification -> async Result;
  }
}