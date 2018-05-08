defmodule TdDd.Repo.Migrations.CreateComments do
  use Ecto.Migration

  def change do
    create table(:comments) do
      add :resource_id, :integer
      add :resource_type, :string
      add :user_id, :integer
      add :content, :string

      timestamps()
    end

  end
end
