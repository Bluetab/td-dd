defmodule TdCx.Repo.Migrations.AddActiveFieldOnSource do
  use Ecto.Migration

  def change do
    alter table(:sources) do
      add :active, :boolean, default: true
    end
  end
end
