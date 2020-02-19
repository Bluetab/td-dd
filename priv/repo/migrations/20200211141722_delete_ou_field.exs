defmodule TdDd.Repo.Migrations.DeleteOuField do
  use Ecto.Migration

  def change do
    alter table("data_structures") do
      remove :ou
    end
  end
end
