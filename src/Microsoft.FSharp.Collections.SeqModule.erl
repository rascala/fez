-module('Microsoft.FSharp.Collections.SeqModule').
-export([
         empty/0,
         singleton/1,
         append/2,
         toList/1,
         ofList/1,
         map/2,
         filter/2,
         delay/1
        ]).

-type enumerator() :: {list, non_neg_integer(), list()}.

-type seq() :: {seq, GetEnumerator :: fun(() -> enumerator())}.


-export_type([seq/0]).

empty() ->
    {seq, fun() -> {list, []} end}.

singleton(Item) ->
    {seq, fun() -> {list, [Item]} end}.

append(Seq1, Seq2) ->
    {seq, fun() -> {append, first, seq(Seq1), seq(Seq2)} end}.

map(F, Seq) ->
    {seq, fun() -> {map, F, seq(Seq)} end}.

filter(Pred, Seq) ->
    {seq, fun() -> {filter, Pred, seq(Seq)} end}.

delay(F) ->
    {seq, fun () -> {delay, F} end}.

toList(Seq) ->
    enumerate(seq(Seq), []).

ofList(List) when is_list(List) ->
    seq(List).

% casts lists (and others) to seq
seq(L) when is_list(L) ->
    {seq, fun() -> {list, L} end};
seq({seq, _} = Seq) ->
    Seq.

enumerate({seq, Seq}, Acc) ->
    enumerate(Seq(), Acc);
enumerate(Enum0, Acc) ->
    case next(Enum0) of
        finished ->
            lists:reverse(Acc);
        {Item, Enum} ->
            enumerate(Enum, [Item | Acc])
    end.

next({seq, GetE}) when is_function(GetE) ->
    next(GetE());
next({seq, EnumOrGetE}) ->
    next(EnumOrGetE);
next({list, [H | Tail]}) ->
    {H, {list, Tail}};
next({list, []}) ->
    finished;
next({map, F, GetE}) when is_function(GetE) ->
    next({map, F, GetE()});
next({map, F, Enum0}) ->
    case next(Enum0) of
        finished -> finished;
        {Item, Enum} ->
            {F(Item), {map, F, Enum}}
    end;
next({filter, P, GetE}) when is_function(GetE) ->
    next({filter, P, GetE()});
next({filter, P, Enum}) ->
    do_filter(P, Enum);
next({append, first, Enum0, Seq2}) ->
    case next(Enum0) of
        finished ->
            next({append, second, Enum0, Seq2});
        {Item, Enum} ->
            {Item, {append, first, Enum, Seq2}}
    end;
next({append, second, Seq1Enum, Enum0}) ->
    case next(Enum0) of
        finished ->
            finished;
        {Item, Enum} ->
            {Item, {append, second, Seq1Enum, Enum}}
    end;
next({delay, F}) ->
    next(seq(F())).

do_filter(P, Enum0) ->
    case next(Enum0) of
        finished -> finished;
        {Item, Enum} ->
            case P(Item) of
                true ->
                    {Item, {filter, P, Enum}};
                false ->
                    do_filter(P, Enum)
            end
    end.


-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").

basics_test() ->
    EmptySeq = empty(),
    [] = toList(EmptySeq),
    Singleton = singleton(1),
    [1] = toList(Singleton),
    ListSeq = ofList([1,2,3]),
    [1,2,3] = toList(ListSeq),
    MapSeq = map(fun(N) -> N * 2 end, ListSeq),
    [2,4,6] = toList(MapSeq),
    MapSeq2 = map(fun(N) -> N * 2 end, MapSeq),
    [4,8,12] = toList(MapSeq2),
    Filter8 = filter(fun(N) -> N =:= 8 end, MapSeq2),
    [8] = toList(Filter8),
    Appended = append(ListSeq, MapSeq),
    [1,2,3,2,4,6] = toList(Appended),
    [1,2,3] = toList(delay(fun () -> ofList([1,2,3]) end)),
    ok.

lists_are_seqs_test() ->
    [1,2,3] = toList([1,2,3]),
    [1,2,3] = toList(delay(fun () -> [1,2,3] end)),
    [1,2] = toList(append([1], [2])),
    ok.


-endif.
