-module(timeit).
-compile(export_all).

%% @doc Dynamically add timing to MFA.  There are various types of
%% timing.
%%
%% all - time latency of all calls to MFA
%%
%% {sample, N, Max} - sample every N calls and stop sampling after Max
%%
%% {threshold, Millis, Max} - count # of calls where latency is > Millis
%% and count # of calls total, thus percentage of calls over threshold
timeit(Mod, Fun, Arity, Type) ->
    Type2 = case Type of
                {sample, N, Max} -> {sample, {N, Max}, {0, 0, 0}};
                {threshold, Millis, Max} -> {threshold, {Millis, Max}, {0, 0}};
                {all, Max} -> {all, {0, Max}}
            end,
    dbg:tracer(process, {fun trace/2, {orddict:new(), Type2}}),
    dbg:p(all, call),
    dbg:tpl(Mod, Fun, Arity, [{'_', [], [{return_trace}]}]).

stop() -> dbg:stop_clear().

trace({trace, Pid, call, {Mod, Fun, _}}, {D, {all, {Count, Max}}}) ->
    D2 = orddict:store({Pid, Mod, Fun}, now(), D),
    {D2, {all, {Count, Max}}};
trace({trace, Pid, call, {Mod, Fun, _}},
      {D, {sample, {N, Max}, {M, K, Total}}}) ->
    M2 = M+1,
    Total2 = Total+1,
    if N == M2 ->
            D2 = orddict:store({Pid, Mod, Fun}, now(), D),
            {D2, {sample, {N, Max}, {0, K, Total2}}};
       true ->
            {D, {sample, {N, Max}, {M2, K, Total2}}}
    end;
trace({trace, Pid, call, {Mod, Fun, _}},
      {D, {threshold, {Millis, Max}, {Over, Total}}}) ->
    D2 = orddict:store({Pid, Mod, Fun}, now(), D),
    {D2, {threshold, {Millis, Max}, {Over, Total+1}}};

trace({trace, Pid, return_from, {Mod, Fun, _}, _Result},
      Acc={D, {all, {Count, Max}}}) ->
    Key = {Pid, Mod, Fun},
    case orddict:find(Key, D) of
        {ok, StartTime} ->
            Count2 = Count+1,
            ElapsedUs = timer:now_diff(now(), StartTime),
            ElapsedMs = ElapsedUs/1000,
            io:format(user, "~p:~p:~p: ~p ms\n", [Pid, Mod, Fun, ElapsedMs]),
            if Count2 == Max -> stop();
               true ->
                    D2 = orddict:erase(Key, D),
                    {D2, {all, {Count2, Max}}}
            end;
        error -> Acc
    end;
trace({trace, Pid, return_from, {Mod, Fun, _}, _Result},
      Acc={D, {sample, {N, Max}, {M, K, Total}}}) ->
    Key = {Pid, Mod, Fun},
    case orddict:find(Key, D) of
        {ok, StartTime} ->
            K2 = K+1,
            ElapsedUs = timer:now_diff(now(), StartTime),
            ElapsedMs = ElapsedUs/1000,
            io:format(user, "[sample ~p/~p] ~p:~p:~p: ~p ms\n",
                      [K2, Total, Pid, Mod, Fun, ElapsedMs]),
            if K2 == Max -> stop();
               true ->
                    D2 = orddict:erase(Key, D),
                    {D2, {sample, {N, Max}, {M, K2, Total}}}
            end;
        error -> Acc
    end;
trace({trace, Pid, return_from, {Mod, Fun, _}, _Result},
      Acc={D, {threshold, {Millis, Max}, {Over, Total}}}) ->
    Key = {Pid, Mod, Fun},
    case orddict:find(Key, D) of
        {ok, StartTime} ->
            ElapsedUs = timer:now_diff(now(), StartTime),
            ElapsedMs = ElapsedUs / 1000,
            if ElapsedMs > Millis ->
                    Over2 = Over+1,
                    io:format(user, "[over threshold ~p, ~p/~p] ~p:~p:~p: ~p ms\n",
                              [Millis, Over2, Total, Pid, Mod, Fun, ElapsedMs]);
               true ->
                    Over2 = Over
            end,
            if Max == Over -> stop();
               true ->
                    D2 = orddict:erase(Key, D),
                    {D2, {threshold, {Millis, Max}, {Over2, Total}}}
            end;
        error -> Acc
    end.


%% timelk() ->
%%     dbg:tracer(process, {fun tracelk/2, []}),
%%     dbg:p(all, call),
%%     dbg:tpl(riak_kv_keys_fsm, start_link, [{'_', [], [{return_trace}]}]).
%%     dbg:tpl(riak_kv_keys_fsm, terminate, [{'_', [], [{return_trace}]}]).


%% tracelk({trace, Pid, call, {riak_kv_keys_fsm, start_link, _}}, Acc) ->
%%     orddict:store(Pid, now(), Acc);
%% tracelk({trace, Pid, return_from, {riak_kv_keys_fsm, terminate, _}, _Result}, Acc) ->
%%     case orddict:find(Pid, Acc) of
%%         {ok, StartTime} ->
%%             ElapsedUs = timer:now_diff(now(), StartTime),
%%             io:format(user, "~p: liskeys ~p us\n", [Pid, ElapsedUs]),
%%             Acc;
%%         error ->
%%             Acc
%%     end;
%% tracelk(_What, Acc) ->
%%     Acc.
