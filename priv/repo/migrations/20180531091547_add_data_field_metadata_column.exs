defmodule TdDd.Repo.Migrations.AddDataFieldModificationsColumn do
  use Ecto.Migration

  def change do
    alter table("data_fields") do
      add :metadata, :map
    end
  end
end
