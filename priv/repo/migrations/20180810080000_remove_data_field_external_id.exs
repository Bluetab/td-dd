defmodule TdDd.Repo.Migrations.RemoveDataFieldExternalId do
  use Ecto.Migration

  def change do
    alter table(:data_fields) do
      remove :external_id
    end
  end
end
