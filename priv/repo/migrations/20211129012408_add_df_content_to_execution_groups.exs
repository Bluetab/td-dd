defmodule TdDd.Repo.Migrations.AddDfContentToExecutionGroups do
  use Ecto.Migration

  def change do
    alter table("execution_groups") do
      add :df_content, :map
    end
  end
end
