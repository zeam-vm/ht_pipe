defmodule HtPipe.MixProject do
  use Mix.Project

  def project do
    [
      app: :ht_pipe,
      version: "0.1.0-dev",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {HtPipe.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:dialyxir, "~> 1.1", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.28", only: :dev, runtime: false},
      {:git_hooks, "~> 0.7", only: [:dev], runtime: false}
    ]
  end

  defp docs do
    [
      main: "HtPipe",
      extras: ["README.md"]
    ]
  end
end
