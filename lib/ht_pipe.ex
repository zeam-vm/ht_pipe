defmodule HtPipe do
  @moduledoc """
  `HtPipe`: Macro for the Heavy Task Pipeline operator.
  """

  @doc """
  Starts a task that can be awaited on with being supervised,
  and temporarily blocks the caller process waiting
  for a task reply with shutdown.

  The task won't be linked to the caller.

  Returns `{:ok, reply}` if the reply is received,
  `nil` if no reply has arrived, or `{:exit, reason}`
  if the task has already exited.
  Keep in mind that normally a task failure also causes
  the process owning the task to exit. Therefore
  this function can return `{:exit, reason}` if at least
  one of the conditions below apply:

  * the task process exited with the reason `:normal`
  * the task isn't linked to the caller due to being supervised
    by this function
  * the caller is trapping exits

  A timeout, in milliseconds or `:infinity`,
  can be given with a default value of `5000`.
  If the time runs out before a message from
  the task is received, this function will return `nil`
  and the monitor will remain active.
  Therefore this function can be called multiple times
  on the same task.

  This function assumes the task's monitor is still active
  or the monitor's `:DOWN` message is in the message queue.
  If it has been demonitored or the message already received,
  this function will wait for the duration of the timeout
  awaiting the message.

  Raises an error if `Task.Supervisor` has reached the maximum
  number of children.

  Note this function requires the task supervisor to have
  `:temporary` as the `:restart` option (the default),
  as this function keeps a direct reference to the task
  which is lost if the task is restarted.
  """
  @spec htp(fun(), non_neg_integer() | atom()) ::
          {:ok, any()} | {:exit | any()} | nil
  def htp(f, timeout \\ 5000) when is_function(f) do
    task = Task.Supervisor.async_nolink(HtPipe.TaskSupervisor, f)
    Task.yield(task, timeout) || Task.shutdown(task)
  end
end
