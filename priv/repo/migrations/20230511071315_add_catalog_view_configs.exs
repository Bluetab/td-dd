defmodule :"Elixir.TdDd.Repo.Migrations.AddCatalogViewConfigs.exs" do
  use Ecto.Migration

  def change do
    create table("catalog_view_configs") do
      add :field_type, :string, null: false
      add :field_name, :string, null: false

      timestamps(type: :utc_datetime_usec)
    end
  end
end
