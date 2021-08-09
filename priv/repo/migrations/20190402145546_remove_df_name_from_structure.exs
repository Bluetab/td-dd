defmodule TdDd.Repo.Migrations.RemoveDfNameFromStructure do
  use Ecto.Migration

  def up do
    alter table("data_structures") do
      remove(:df_name)
    end
  end

  def down do
    alter table("data_structures") do
      add(:df_name, :string)
    end
  end
end
