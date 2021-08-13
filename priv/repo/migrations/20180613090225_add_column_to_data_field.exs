defmodule TdDd.Repo.Migrations.AddColumnToDataField do
  use Ecto.Migration

  def change do
    alter table("data_fields") do
      add :external_id, :string, null: true
    end
  end
end
