defmodule HtPipe do
  @moduledoc """
  `HtPipe`: Macro for the Heavy Task Pipeline operator.
  """

  def htp(f, timeout \\ 5000) when is_function(f) do
    task = Task.Supervisor.async_nolink(HtPipe.TaskSupervisor, f)
    Task.yield(task, timeout) || Task.shutdown(task)
  end
end
