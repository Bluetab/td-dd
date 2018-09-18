defmodule TdDq.Repo.Migrations.ChangeNameField do
  use Ecto.Migration

  def change do
    rename table(:rule_implementations), :name, to: :implementation_key
  end
end
