defmodule TdDd.Repo.Migrations.AddOban do
  use Ecto.Migration

  def up, do: Oban.Migration.up(prefix: Application.get_env(:td_dd, Oban)[:prefix])

  def down,
    do: Oban.Migration.down(prefix: Application.get_env(:td_dd, Oban)[:prefix], version: 1)
end
