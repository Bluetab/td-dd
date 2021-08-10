defmodule TdDd.Repo.Migrations.CreatePartialIndexSystemIdExternalId do
  use Ecto.Migration

  def change do
    drop unique_index("data_structures", [:system_id, :group, :name, :external_id])

    create unique_index("data_structures", [:system_id, :external_id],
             where: "external_id IS NOT NULL"
           )

    create unique_index("data_structures", [:system_id, :group, :name],
             where: "external_id IS NULL"
           )
  end
end
