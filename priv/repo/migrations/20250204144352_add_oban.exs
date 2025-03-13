defmodule TdDd.Repo.Migrations.AddOban do
  use Ecto.Migration

  def up,
    do:
      Oban.Migration.up(
        prefix: Application.get_env(:td_dd, Oban)[:prefix],
        oban_create_schema: Application.get_env(:td_dd, Oban)
      )

  def down,
    do: Oban.Migration.down(prefix: Application.get_env(:td_dd, Oban)[:prefix], version: 1)
end
