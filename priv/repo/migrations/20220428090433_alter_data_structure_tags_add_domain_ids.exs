defmodule TdDd.Repo.Migrations.AlterDataStructureTagsAddDomainIds do
  use Ecto.Migration

  def change do
    alter table("data_structure_tags") do
      add :domain_ids, {:array, :integer}, default: [], null: false
    end
  end
end
