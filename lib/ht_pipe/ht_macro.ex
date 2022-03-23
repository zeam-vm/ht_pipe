defmodule HtPipe.HtMacro do
  @moduledoc """
    Description of `HtPipe.HtMacro`.
  """

  # defp replace_pipe_to_ht_pipe(fun) do
  #  Macro.prewalk(fun, fn
  #    {:|>, meta, children} -> {:ht_pipe, meta, children}
  #    other -> other
  #  end)
  # end

  defmacro ht_pipe_fun(fun, _timeout) do
    Macro.postwalk(fun, fn
      {:|>, meta, [left, right]} ->
        {:|>, meta, [left, right]}

      other ->
        other
    end)
  end

  @doc """
    Splits AST into pipe and others and returns a tuple of
    the original AST and another tuple that has a keyword list,
    the numbers of pipes and others.

    The key and the value of the keyword list are
    an identifier of the pipe or the other, and its AST fragment,
    respectively.

  ## Examples
      iex> HtPipe.HtMacro.split_pipe_other(quote do: [1, 2, 3] |> Enum.map(& &1 * 2))
      {{:|>, [context: HtPipe.HtMacroTest, import: Kernel],
        [
          [1, 2, 3],
          {{:., [], [{:__aliases__, [alias: false], [:Enum]}, :map]}, [],
           [{:&, [], [{:*, [context: HtPipe.HtMacroTest, import: Kernel], [{:&, [], [1]}, 2]}]}]}
        ]},
      {[
          p0: {:|>, [context: HtPipe.HtMacroTest, import: Kernel],
          [
            [1, 2, 3],
            {{:., [], [{:__aliases__, [alias: false], [:Enum]}, :map]}, [],
            [
              {:&, [],
               [{:*, [context: HtPipe.HtMacroTest, import: Kernel], [{:&, [], [1]}, 2]}]}
            ]}
          ]},
        o0: [1, 2, 3],
        o1: 1,
        o2: 2,
        o3: 3,
        o4: {{:., [], [{:__aliases__, [alias: false], [:Enum]}, :map]}, [],
          [{:&, [], [{:*, [context: HtPipe.HtMacroTest, import: Kernel], [{:&, [], [1]}, 2]}]}]},
        o5: {:., [], [{:__aliases__, [alias: false], [:Enum]}, :map]},
        o6: {:__aliases__, [alias: false], [:Enum]},
        o7: :Enum,
        o8: :map,
        o9: {:&, [], [{:*, [context: HtPipe.HtMacroTest, import: Kernel], [{:&, [], [1]}, 2]}]},
        o10: {:*, [context: HtPipe.HtMacroTest, import: Kernel], [{:&, [], [1]}, 2]},
        o11: {:&, [], [1]},
        o12: 1,
        o13: 2
      ], 1, 14}}
  """
  @spec split_pipe_other(Macro.t()) ::
          {
            Macro.t(),
            {
              Keyword.t(Macro.t()),
              non_neg_integer(),
              non_neg_integer()
            }
          }
  def split_pipe_other(ast) do
    Macro.prewalk(ast, {[], 0, 0}, fn
      pipe = {:|>, _, _}, {keyword, pipe_id, other_id} ->
        case Keyword.get(keyword, pa = :"p#{pipe_id}") do
          nil ->
            {
              pipe,
              {
                keyword ++ [{pa, pipe}],
                pipe_id + 1,
                other_id
              }
            }

          _ ->
            {
              pipe,
              {
                keyword,
                pipe_id,
                other_id
              }
            }
        end

      other, {keyword, pipe_id, other_id} ->
        case Keyword.get(keyword, oa = :"o#{other_id}") do
          nil ->
            {
              other,
              {
                keyword ++ [{oa, other}],
                pipe_id,
                other_id + 1
              }
            }

          _ ->
            {
              other,
              {
                keyword,
                pipe_id,
                other_id
              }
            }
        end
    end)
  end

  @doc """
    Removes the tail element from the given list.

  ## Examples
      iex>  HtPipe.HtMacro.remove_tail([1, 2, 3])
      [1, 2]
  """
  @spec remove_tail(nonempty_list()) :: list()
  def remove_tail(list) do
    list |> Enum.reverse() |> tl() |> Enum.reverse()
  end

  @doc """
    Unpipes all values of the given keyword list.
  """
  @spec map_unpipe_value_of_keyword(Keyword.t(Macro.t())) ::
          Keyword.t(list({Macro.t(), integer()}))
  def map_unpipe_value_of_keyword(ast_keyword_list) do
    Enum.map(
      ast_keyword_list,
      fn {id, ast} -> {id, Macro.unpipe(ast)} end
    )
  end

  @doc """
    Extracts pipes or others from the given keyword list.

  ## Examples
      iex> HtPipe.HtMacro.extract_pipes_or_others([e1: 0, f1: 2], :e)
      [e1: 0]
  """
  @spec extract_pipes_or_others(Keyword.t(), atom) :: Keyword.t()
  def extract_pipes_or_others(keyword_list, atom) do
    keyword_list
    |> Enum.filter(fn {id, _} -> String.starts_with?(Atom.to_string(id), Atom.to_string(atom)) end)
  end

  @doc """
    Extracts the maxium pipes from the given keyword list.
  """
  @spec extract_max_pipe(Keyword.t(list({Macro.t(), integer()}))) ::
          Keyword.t(list({Macro.t(), integer()}))
  def extract_max_pipe(unpiped_ast_kl) do
    kl = Keyword.keys(unpiped_ast_kl)
    vl = Keyword.values(unpiped_ast_kl)

    Enum.zip([kl, vl, [[:dummy]] ++ vl])
    |> Enum.reject(fn {_k, x, y} -> x == remove_tail(y) end)
    |> Enum.map(fn {k, x, _} -> {k, x} end)
  end

  def extract_max_pipes_from_ast(ast) do
    {_ast, {ast_keyword_list, _num_pipe, _num_other}} = split_pipe_other(ast)

    ast_keyword_list
    |> extract_pipes_or_others(:p)
    |> map_unpipe_value_of_keyword()
    |> extract_max_pipe()
  end
end
