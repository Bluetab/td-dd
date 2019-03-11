defmodule TdDq.Mixfile do
  use Mix.Project
  alias Mix.Tasks.Phx.Swagger.Generate, as: PhxSwaggerGenerate

  def project do
    [
      app: :td_dq,
      version: case System.get_env("APP_VERSION") do nil -> "2.6.0-local"; v -> v end,
      elixir: "~> 1.4",
      elixirc_paths: elixirc_paths(Mix.env),
      compilers: [:phoenix, :gettext] ++ Mix.compilers,
      start_permanent: Mix.env == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {TdDq.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.3.0"},
      {:phoenix_pubsub, "~> 1.0"},
      {:phoenix_ecto, "~> 3.2"},
      {:postgrex, ">= 0.0.0"},
      {:gettext, "~> 0.11"},
      {:httpoison, "~> 1.0"},
      {:cowboy, "~> 1.0"},
      {:credo, "~> 0.9.3", only: [:dev, :test], runtime: false},
      {:edeliver, "~> 1.4.5"},
      {:distillery, ">= 0.8.0", warn_missing: false},
      {:guardian, "~> 1.0"},
      {:comeonin, "~> 4.0"},
      {:bcrypt_elixir, "~> 1.0"},
      {:cabbage, "~> 0.3.0"},
      {:phoenix_swagger, "~> 0.8.0"},
      {:ex_json_schema, "~> 0.5"},
      {:csv, "~> 2.0.0"},
      {:timex, "~> 3.1"},
      {:ex_machina, "~> 2.1", only: :test},
      {:canada, "~> 1.0.1"},
      {:td_perms, git: "https://github.com/Bluetab/td-perms.git", tag: "2.15.0"},
      {:td_df_lib, git: "https://github.com/Bluetab/td-df-lib.git", tag: "2.15.0"},
      {:td_hypermedia, git: "https://github.com/Bluetab/td-hypermedia.git", tag: "v0.1.2"}
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
      "test": ["ecto.create --quiet", "ecto.migrate", "run priv/repo/seeds.exs", "test"],
      "compile": ["compile", &pxh_swagger_generate/1]
    ]
  end

  defp pxh_swagger_generate(_) do
      if Mix.env in [:dev, :prod] do
        PhxSwaggerGenerate.run(["priv/static/swagger.json"])
      end
  end
end
