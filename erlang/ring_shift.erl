-module(ring_shift).
-compile(export_all).

run(Name, Rings) ->
    TargetN = 4,

    application:load(riak_core),
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

    {ok, Out} =
        file:open(list_to_atom(lists:flatten(io_lib:format("/tmp/shift_~s.txt",
                                                           [Name]))),
                  [read, write]),
    [print_info(Out, O, M, Meets, RingSize, I, Paths)
     || {I, O, M} <- lists:zip3(lists:seq(1,length(Owners)), Owners, Movers)].

print_info(Out, Owners, PartitionsMoved, Meets, RingSize, I, Paths) ->
    Percent = 100 * (PartitionsMoved / RingSize),

    F = fun({_,Node}, Acc) ->
                dict:update_counter(Node, 1, Acc)
        end,
    Counts = lists:keysort(1, dict:to_list(lists:foldl(F, dict:new(), Owners))),
    io:format(Out, "from ~p to ~p, ~n=> actual=~p, percent=~p, meets_target_n=~p~n"
              "counts: ~p~n~n",
              [lists:nth(I, Paths), lists:nth(I+1, Paths),
               PartitionsMoved, Percent, lists:nth(I, Meets), Counts]).

not_same_node({{P,N}, {P,N}}) -> false;
not_same_node({{P,_N}, {P,_M}}) -> true.
