defmodule TdDd.Repo.Migrations.DropDataStructuresAlias do
  use Ecto.Migration

  def change do
    alter table("data_structures") do
      remove :alias, :string
    end

    
  end
end
