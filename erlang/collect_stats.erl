-module(collect_stats).
-compile(export_all).

-define(FMT(S, A), lists:flatten(io_lib:format(S, A))).

%% TODO lookup log dir -- {riak_core, platform_log_dir}
-spec run(string()) -> none().
run(Name) ->
    case ets:info(?MODULE) of
        undefined -> ets:new(?MODULE, [ordered_set, public, named_table]);
        _ -> ok
    end,

    GossipFile = ?FMT("/var/log/riak/gossip_stat~s.out", [Name]),
    {ok, IO1} = file:open(GossipFile, [write, exclusive]),
    io:format(IO1, "moment gossip_received~n", []),
    Pid1 = spawn(?MODULE, collect_gossip, [IO1]),

    TransfersFile = ?FMT("/var/log/riak/transfers_stat~s.out", [Name]),
    {ok, IO2} = file:open(TransfersFile, [write, exclusive]),
    io:format(IO2, "moment pending delta~n", []),
    Pid2 = spawn(?MODULE, collect_transfers, [IO2]),

    RingFile = ?FMT("/var/log/riak/ring_stat~s.out", [Name]),
    {ok, IO3} = file:open(RingFile, [write, exclusive]),
    io:format(IO3, "moment nodes partitions_moved percent meets_n~n", []),
    spawn(?MODULE, collect_rings, [IO3]),

    MBFile = ?FMT("/var/log/riak/mb_stat~s.out", [Name]),
    {ok, IO4} = file:open(MBFile, [write, exclusive]),
    io:format(IO4, "moment riak_core_gossip riak_core_vnode_manager riak_core_ring_events~n", []),
    Pid4 = spawn(?MODULE, collect_mailbox_len, [IO4]),
    
    Pids = case ets:lookup(?MODULE, pids) of
               [{pids,Pids2}] -> Pids2;
               [] -> []
           end,
    true = ets:insert(?MODULE, {pids, Pids ++ [Pid1, Pid2, Pid4]}),
    
    IOs = case ets:lookup(?MODULE, io) of
              [{io, IOs2}] -> IOs2;
              [] -> []
          end,
    true = ets:insert(?MODULE, {io, IOs ++ [IO1, IO2, IO3, IO4]}).

stop() ->
    [{pids,Pids}] = ets:lookup(?MODULE, pids),
    [exit(P, kill) || P <- Pids],
    [{hdlrs,Hdlrs}] = ets:lookup(?MODULE, hdlrs),
    [gen_event:delete_handler(riak_core_ring_events, H, []) || H <- Hdlrs],
    [{io,IOs}] = ets:lookup(?MODULE, io),
    [file:close(IO) || IO <- IOs],
    ets:delete(?MODULE).
    

-spec collect_gossip(file:io_device()) -> none().
collect_gossip(IO) ->
    Stats = riak_core_stat:get_stats(),
    Gossip = proplists:get_value(gossip_received, Stats),
    io:format(IO, "~s ~p~n", [moment(), Gossip]),
    timer:sleep(timer:minutes(1)),
    collect_gossip(IO).

-spec collect_transfers(file:io_device()) -> none().
collect_transfers(IO) ->
    collect_transfers(IO, transfers_pending()).

-spec collect_transfers(file:io_device(), Pending::non_neg_integer()) -> none().
collect_transfers(IO, Pending) ->
    LatestPending = transfers_pending(),
    Delta = -(Pending - LatestPending),
    io:format(IO, "~s ~p ~p~n", [moment(), LatestPending, Delta]),
    timer:sleep(timer:minutes(1)),
    collect_transfers(IO, LatestPending).

-spec collect_rings(file:io_device()) -> none().
collect_rings(IO) ->
    {ok, Ring} = riak_core_ring_manager:get_my_ring(),
    true = ets:insert(?MODULE, {last, Ring}),
    riak_core_ring_events:add_callback(print_ring(IO)),
    Hdlr = hd(gen_event:which_handlers(riak_core_ring_events)),
    case ets:lookup(?MODULE, hdlrs) of
        [] -> ets:insert(?MODULE, {hdlrs, [Hdlr]});
        [{hdlrs, H}] -> ets:insert(?MODULE, {hdlrs, H ++ [Hdlr]})
    end.
    %% collect_rings_loop(IO).

-spec collect_mailbox_len(file:io_device()) -> none().
collect_mailbox_len(IO) ->
    Names = [riak_core_gossip, riak_core_vnode_manager, riak_core_ring_events],
    Pids = lists:map(fun erlang:whereis/1, Names),
    Lens = lists:map(fun ?MODULE:mb_len/1, Pids),
    case lists:any(fun positive/1, Lens) of
        true -> io:format(IO, "~s ~p ~p ~p~n", [moment()] ++ Lens);
        false -> ok
    end,
    timer:sleep(timer:seconds(1)),
    collect_mailbox_len(IO).

-spec mb_len(pid()) -> non_neg_integer().
mb_len(Pid) ->
    {_, Len} = erlang:process_info(Pid, message_queue_len),
    Len.

-spec positive(integer()) -> boolean().
positive(N) ->
    if N > 0 -> true;
       true -> false
    end.
%% -spec collect_rings_loop(file:io_device()) -> none().
%% collect_rings_loop(IO) ->
%%     {First, Last} = get_first_and_last_ring(),
%%     {AbsoluteChurn, PercentChurn} = calc_churn(First, Last),
%%     io:format(IO, "~s ring-churn ~p ~p",
%%               [moment(), AbsoluteChurn, PercentChurn]),
%%     timer:sleep(timer:minutes(1)),
%%     collect_rings_loop(IO).

%% -spec put_ring(Ring::term()) -> ok.
%% put_ring(R) ->
%%     true = ets:insert(rings, {now(), R}),
%%     ok.

-spec print_ring(file:io_device()) -> fun((Ring::term()) -> none()).
print_ring(IO) ->
    fun(Ring) ->
            [{last, LastRing}] = ets:lookup(?MODULE, last),
            [ok] = ring_churn(IO, [LastRing, Ring]),
            true = ets:insert(?MODULE, {last, Ring})
    end.

%% -spec get_first_and_last_ring() -> {FirstRing::term(), LastRing::term()}.
%% get_first_and_last_ring() ->
%%     {_, FirstRing} = ets:lookup(?MODULE, ets:first(rings)),
%%     {_, LastRing} = ets:lookup(?MODULE, ets:last(rings)),
%%     {FirstRing, LastRing}.
    
-spec transfers_pending() -> Pending::non_neg_integer().
transfers_pending() ->
    {ok, Ring} = riak_core_ring_manager:get_my_ring(),
    {_Primary, Secondary, _Stopped} = partitions(node(), Ring),
    length(Secondary).

-spec moment() -> ISO8601::string().
moment() ->
    {{YYYY,MM,DD}, {HH,MI,SS}} = calendar:local_time(),
    ?FMT("~4..0B-~2..0B-~2..0BT~2..0B:~2..0B:~2..0B", [YYYY,MM,DD,HH,MI,SS]).
    

%% Return a list of active primary partitions, active secondary partitions (to be handed off)
%% and stopped partitions that should be started
%%
%% Copied verbatim from riak_core_status.
partitions(Node, Ring) ->
    Owners = riak_core_ring:all_owners(Ring),
    Owned = ordsets:from_list(owned_partitions(Owners, Node)),
    Active = ordsets:from_list(active_partitions(Node)),
    Stopped = ordsets:subtract(Owned, Active),
    Secondary = ordsets:subtract(Active, Owned),
    Primary = ordsets:subtract(Active, Secondary),
    {Primary, Secondary, Stopped}.

owned_partitions(Owners, Node) ->
    [P || {P, Owner} <- Owners, Owner =:= Node].

active_partitions(Node) ->
    lists:foldl(fun({_,P}, Ps) ->
                        ordsets:add_element(P, Ps)
                end, [], running_vnodes(Node)).

%% Get a list of running vnodes for a node
running_vnodes(Node) ->
    [{Mod,Idx} || {Mod, Idx, _} <- rpc:call(Node, riak_core_vnode_manager, all_vnodes, [])].
    %% Pids = vnode_pids(Node),
    %% [rpc:call(Node, riak_core_vnode, get_mod_index, [Pid], 30000) || Pid <- Pids].

%% Get a list of vnode pids for a node
vnode_pids(Node) ->
    [Pid || {_,Pid,_,_} <- supervisor:which_children({riak_core_vnode_sup, Node})].

-spec ring_churn(file:io_device(), [Ring::term()]) -> [ok].
ring_churn(IO, Rings) ->
    TargetN = 4,

    RingSize = riak_core_ring:num_partitions(hd(Rings)),
    Owners1 = riak_core_ring:all_owners(hd(Rings)),
    Owners = lists:map(fun riak_core_ring:all_owners/1, tl(Rings)),

    {Movers, _} =
        lists:mapfoldl(
          fun(Curr, Prev) ->
                  Sum = length(lists:filter(fun not_same_node/1,
                                            lists:zip(Prev, Curr))),
                  {Sum, Curr}
          end, Owners1, Owners),

    Meets = [riak_core_claim:meets_target_n(R, TargetN) || R <- tl(Rings)],

    [print_ring_info(IO, O, M, Meets, RingSize, I)
     || {I, O, M} <- lists:zip3(lists:seq(1,length(Owners)), Owners, Movers)].

-spec print_ring_info(file:io_device(), list(), non_neg_integer(), [boolean()], non_neg_integer(), non_neg_integer()) -> ok.
print_ring_info(Out, Owners, PartitionsMoved, Meets, RingSize, I) ->
    Percent = 100 * (PartitionsMoved / RingSize),

    io:format(Out, "~s ~p ~p ~p ~p~n",
              [moment(), length(nodes()) + 1, PartitionsMoved, Percent, lists:nth(I, Meets)]).

not_same_node({{P,N}, {P,N}}) -> false;
not_same_node({{P,_N}, {P,_M}}) -> true.
