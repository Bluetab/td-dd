defmodule TdCx.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  def change do
    create table(:events) do
      add :date, :utc_datetime
      add :type, :string
      add :message, :text
      add :job_id, references(:jobs), null: false

      timestamps()
    end

  end
end
