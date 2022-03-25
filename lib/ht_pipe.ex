defmodule HtPipe do
  @moduledoc """
  `HtPipe`: Macro for the Heavy Task Pipeline operator.
  """

  @sub_elixir_alive_time 100_000

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

  ## Options

  * `:timeout` - a timeout, in milliseconds or `:infinity`,
  can be given with a default value of `5000`.
  If the time runs out before a message from
  the task is received, this function will return `nil`
  and the monitor will remain active.
  Therefore this function can be called multiple times
  on the same task.

  * `:spawn` - the spawn strategy, may be `:inner` (the default)
    or `:os`. `:inner` means to spawn a light-weight process
    monitored by `Task.Supervisor`. `:os` means to spawn an
    os-level process using `Port` and `Node`, which is robust
    against situations where the entire Erlang VM terminates
    abnormally, for example a NIF abort, but it reduces
    the efficiency of parameter passing.
  """
  @spec htp(fun(), keyword()) ::
          {:ok, any()} | {:exit | any()} | nil
  def htp(f, options \\ []) when is_function(f) do
    timeout =
      options
      |> Keyword.get(:timeout, 5000)

    spawn =
      options
      |> Keyword.get(:spawn, :inner)

    htp_p(f, timeout, spawn)
  end

  defp htp_p(f, timeout, :inner) do
    task = Task.Supervisor.async_nolink(HtPipe.TaskSupervisor, f)
    Task.yield(task, timeout) || Task.shutdown(task)
  end

  defp htp_p(f, timeout, :os) do
    if spawn_sub_elixir() do
      Node.spawn(htp_worker(), __MODULE__, :worker, [self(), timeout, f])
      Process.sleep(100)

      result =
        receive do
          e -> e
        after
          timeout -> nil
        end

      result
    else
      nil
    end
  end

  @doc """
    Spawns Elixir sub os process with `Node` setting.

    This process will terminate after `@sub_elixr_alive_time` msec.
  """
  @spec spawn_sub_elixir() :: true | false
  def spawn_sub_elixir() do
    unless Node.alive?() do
      # TODO set up Node
    end

    unless wait_for_connect_htp_worker(100) do
      Task.async(fn ->
        System.cmd(
          "elixir",
          [
            "--name",
            htp_worker() |> Atom.to_string(),
            "--cookie",
            Node.get_cookie() |> Atom.to_string(),
            "-S",
            "mix",
            "run",
            "-e",
            "Process.sleep(#{@sub_elixir_alive_time})"
          ]
        )
      end)
    end

    wait_for_connect_htp_worker(100)
  end

  @doc false
  @spec worker(pid(), non_neg_integer() | atom(), fun()) ::
          {:ok, any()} | {:exit | any()} | nil
  def worker(receiver, timeout, f) do
    send(receiver, HtPipe.htp(f, timeout: timeout, spawn: :inner))
  end

  @doc """
    Waits for and tests the connection between the self process
    and the worker of the sub elixir process.

    A timeout, in milliseconds can be given with a default value
    of `1000`.
  """
  @spec wait_for_connect_htp_worker(integer) :: true | false
  def wait_for_connect_htp_worker(timeout \\ 1000)

  def wait_for_connect_htp_worker(timeout) when timeout > 0 do
    case {Node.connect(htp_worker()), Node.ping(htp_worker())} do
      {true, :pong} ->
        true

      _ ->
        Process.sleep(100)
        wait_for_connect_htp_worker(timeout - 100)
    end
  end

  def wait_for_connect_htp_worker(_), do: false

  @doc """
    Halts the worker of the sub elixir process.
  """
  @spec halt_htp_worker() :: :ok
  def halt_htp_worker() do
    case Node.ping(htp_worker()) do
      :pong ->
        Node.spawn(htp_worker(), &System.halt/0)
        :ok

      :pang ->
        :ok
    end
  end

  @doc """
    Gets the node of the worker.
  """
  @spec htp_worker() :: atom()
  def htp_worker() do
    [sname, hostname] = Node.self() |> get_listname_from_nodename()
    :"htp_worker_#{sname}@#{hostname}"
  end

  defp get_listname_from_nodename(node_name) do
    node_name |> Atom.to_string() |> String.split("@")
  end

  @doc """
    Gets the short name of the node.
  """
  @spec get_sname_from_nodename(atom()) :: String.t()
  def get_sname_from_nodename(node_name) do
    node_name |> get_listname_from_nodename() |> Enum.at(0)
  end

  @doc """
    Gets the host name of the node.
  """
  @spec get_hostname_from_nodename(atom()) :: String.t()
  def get_hostname_from_nodename(node_name) do
    node_name |> get_listname_from_nodename() |> Enum.at(1)
  end
end
