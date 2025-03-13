defmodule TdDd.Repo.Migrations.AddOban do
  use Ecto.Migration

  def up,
    do:
      Oban.Migration.up(
        prefix: Application.get_env(:td_dd, Oban)[:prefix],
        create_schema: Application.get_env(:td_dd, Oban)[:create_schema]
      )

  def down,
    do: Oban.Migration.down(prefix: Application.get_env(:td_dd, Oban)[:prefix], version: 1)
end
