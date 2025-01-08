defmodule TdDd.Repo.Migrations.AlterDataStructuresExternalIdUnique do
  use Ecto.Migration

  def change do
    alter table("data_structures") do
      modify(:external_id, :text, null: false)
    end

    drop unique_index("data_structures", [:system_id, :external_id],
           where: "external_id IS NOT NULL"
         )

    drop unique_index("data_structures", [:system_id, :group, :name],
           where: "external_id IS NULL"
         )

    create unique_index("data_structures", [:external_id])
  end
end
