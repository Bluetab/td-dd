defmodule TdDd.Repo.Migrations.AlterDataStructureSourceId do
  use Ecto.Migration

  def up do
    alter table("data_structures") do
      modify(:source_id, references("sources", on_delete: :nilify_all))
    end
  end

  def down do
    drop constraint("data_structures", :data_structures_source_id_fkey)

    alter table("data_structures") do
      modify(:source_id, :integer, default: nil, null: true)
    end
  end
end
