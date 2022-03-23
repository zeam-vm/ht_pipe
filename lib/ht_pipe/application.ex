defmodule HtPipe.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: HtPipe.Worker.start_link(arg)
      # {HtPipe.Worker, arg}
      {Task.Supervisor, name: HtPipe.TaskSupervisor}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: HtPipe.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
