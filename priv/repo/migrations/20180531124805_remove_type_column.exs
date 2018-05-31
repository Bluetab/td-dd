defmodule TdDq.Repo.Migrations.RemoveTypeColumn do
  use Ecto.Migration

  def change do
    alter table("quality_controls") do
      remove :type
    end
  end
end
