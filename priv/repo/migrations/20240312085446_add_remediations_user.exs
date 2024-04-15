defmodule TdDd.Repo.Migrations.AddRemediationsUser do
  use Ecto.Migration

  def change do
    alter table("remediations") do
      add :user_id, :bigint
    end
  end
end
