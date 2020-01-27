defmodule TdDd.Mixfile do
  use Mix.Project

  def project do
    [
      app: :td_dd,
      version:
        case System.get_env("APP_VERSION") do
          nil -> "3.14.0-local"
          v -> v
        end,
      elixir: "~> 1.6",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers() ++ [:phoenix_swagger],
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {TdDd.Application, []},
      extra_applications: [:logger, :runtime_tools, :td_cache]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.4.0"},
      {:plug_cowboy, "~> 2.0"},
      {:plug, "~> 1.7"},
      {:phoenix_ecto, "~> 4.0", override: true},
      {:ecto_sql, "~> 3.0"},
      {:jason, "~> 1.0"},
      {:postgrex, ">= 0.0.0"},
      {:gettext, "~> 0.11"},
      {:cabbage, only: [:test], git: "https://github.com/Bluetab/cabbage", tag: "v0.3.7-alpha"},
      {:httpoison, "~> 1.6.2"},
      {:distillery, "~> 2.0", runtime: false},
      {:credo, "~> 1.0.0", only: [:dev, :test], runtime: false},
      {:guardian, "~> 1.0"},
      {:canada, "~> 1.0.1"},
      {:ex_machina, "~> 2.2.2", only: [:test]},
      {:cors_plug, "~> 1.2"},
      {:csv, "~> 2.2.0"},
      {:phoenix_swagger, "~> 0.8.2"},
      {:ex_json_schema, "~> 0.7.3"},
      {:elasticsearch,
       git: "https://github.com/Bluetab/elasticsearch-elixir.git",
       branch: "feature/bulk-index-action"},
      {:td_cache, git: "https://github.com/Bluetab/td-cache.git", tag: "3.9.1"},
      {:td_hypermedia, git: "https://github.com/Bluetab/td-hypermedia.git", tag: "3.6.1"},
      {:td_df_lib, git: "https://github.com/Bluetab/td-df-lib.git", tag: "3.14.0"},
      {:poison, "~> 3.1"}
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
      test: ["ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end
end
