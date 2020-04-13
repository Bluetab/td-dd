defmodule TdDq.Repo.Migrations.ChangeResultToFloat do
  use Ecto.Migration

  def change do
    alter table(:rule_results) do
      modify(:result, :decimal, scale: 2, precision: 5)
    end
  end
end
