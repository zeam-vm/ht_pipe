defmodule HtPipe do
  require HtPipe.HtMacro

  @moduledoc """
  `HtPipe`: Macro for the Heavy Task Pipeline operator.

  If you write the following:

  ```
  HtPipe.ht_pipe(fn ->
      [1, 2, 3]
      |> Enum.map(& &1 * 2)
    end,
    timeout
  )
  ```

  Elixir executes as follows:

  ```
  fn ->
    case HtPipe.htp(fn ->
          [1, 2, 3]
          |> Enum.map(& &1 * 2)
        end,
        timeout
      ) do
      {:ok, result} -> {:ok, result}
      other -> other
    end
  end.()
  ```

  If you write the following:

  ```
  HtPipe.ht_pipe(fn ->
      [1, 2, 3]
      |> Enum.map(& &1 * 2)
      |> Enum.map(& &1 + 1)
    end,
    timeout
  )
  ```

  Elixir executes as follows:

  ```
  fn ->
    case HtPipe.htp(fn ->
          [1, 2, 3]
          |> Enum.map(& &1 * 2)
        end,
        timeout
      ) do
      {:ok, result} ->
        case HtPipe.htp(fn ->
              result
              |> Enum.map(& &1 + 1)
            end,
            timeout
          ) do
          {:ok, result} -> {:ok, result}
          other -> other
        end
      other -> other
    end
  end.()
  ```
  """

  def htp(f, timeout \\ 5000) when is_function(f) do
    task = Task.Supervisor.async_nolink(HtPipe.TaskSupervisor, f)
    Task.yield(task, timeout) || Task.shutdown(task)
  end

  defmacro ht_pipe(fun, timeout \\ 5000) do
    {{:., [],
      [
        {{:., [], [{:__aliases__, [alias: false], [:HtPipe, :HtMacro]}, :ht_pipe_fun]}, [],
         [fun, timeout]}
      ]}, [], []}
  end
end
