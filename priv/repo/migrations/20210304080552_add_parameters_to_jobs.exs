defmodule TdCx.Repo.Migrations.AddParametersToJobs do
  use Ecto.Migration

  def change do
    alter table("jobs") do
      add :parameters, :map, default: %{}
    end
  end
end
