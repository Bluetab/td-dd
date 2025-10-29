defmodule TdDd.MixProject do
  use Mix.Project

  def project do
    [
      app: :td_dd,
      version:
        case System.get_env("APP_VERSION") do
          nil -> "7.12.0-local"
          v -> v
        end,
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      releases: [
        td_dd: [
          include_executables_for: [:unix],
          applications: [runtime_tools: :permanent],
          steps: [:assemble, &copy_bin_files/1, :tar]
        ]
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {TdDd.Application, []},
      extra_applications: [:logger, :runtime_tools, :td_cache, :vaultex]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp copy_bin_files(release) do
    File.cp_r("rel/bin", Path.join(release.path, "bin"))
    release
  end

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.7.18"},
      {:phoenix_ecto, "~> 4.6.3"},
      {:phoenix_view, "~> 2.0"},
      {:plug_cowboy, "~> 2.7"},
      {:absinthe, "~> 1.7.8"},
      {:absinthe_plug, "~> 1.5.8"},
      {:crudry, "~> 2.4.0"},
      {:dataloader, "~> 2.0.1"},
      {:ecto_sql, "~> 3.12.1"},
      {:postgrex, "~> 0.19.3"},
      {:jason, "~> 1.4.4"},
      {:httpoison, "~> 2.2.1", override: true},
      {:credo, "~> 1.7.11", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4.5", only: :dev, runtime: false},
      {:ex_machina, "~> 2.8", only: :test},
      {:guardian, "~> 2.3.2"},
      {:bodyguard, "~> 2.4.3"},
      {:quantum, "~> 3.5.3"},
      {:mox, "~> 1.2", only: :test},
      {:assertions, "~> 0.20.1", only: :test},
      {:inflex, "~> 2.1"},
      {:cors_plug, "~> 3.0.3"},
      {:csv, "~> 3.2.1"},
      {:nimble_csv, "~> 1.2"},
      {:tzdata, "~> 1.1.2"},
      {:flow, "~> 1.2.4"},
      {:codepagex, "~> 0.1.9"},
      {:bimap, "~> 1.3"},
      {:td_core, git: "https://github.com/Bluetab/td-core.git", tag: "7.12.0"},
      {:vaultex, "~> 1.0.1"},
      {:sobelow, "~> 0.13", only: [:dev, :test]},
      {:elixlsx, "~> 0.6"},
      {:xlsx_reader, "~> 0.8.7"},
      {:igniter, "~> 0.5"},
      {:oban, "~> 2.19"},
      {:flop, "~> 0.26.1"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
