defmodule TdDd.Repo.Migrations.AddDfContentToSystem do
  use Ecto.Migration

  def change do
    alter table("systems") do
      add :df_content, :map
    end
  end
end
