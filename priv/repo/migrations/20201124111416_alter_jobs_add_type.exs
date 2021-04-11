defmodule TdCx.Repo.Migrations.AlterJobsAddType do
  use Ecto.Migration

  def change do
    alter table(:jobs) do
      add(:type, :string)
    end
  end
end
