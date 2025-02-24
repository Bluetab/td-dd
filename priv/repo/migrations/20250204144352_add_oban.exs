defmodule TdDd.Repo.Migrations.AddOban do
  use Ecto.Migration

  def up, do: Oban.Migration.up(prefix: "private")

  def down, do: Oban.Migration.down(prefix: "private", version: 1)
end
