defmodule TdDd.Repo.Migrations.CreateGraphModel do
  use Ecto.Migration

  def change do
    create table(:units) do
      add(:name, :string, null: false)
      add(:deleted_at, :utc_datetime_usec, null: true)
      timestamps(type: :utc_datetime_usec)
    end

    create table(:unit_events) do
      add(:unit_id, references(:units, on_delete: :delete_all), null: false)
      add(:event, :string, null: false)
      add(:info, :map, null: true)
      add(:inserted_at, :utc_datetime_usec, null: false)
    end

    create table(:nodes) do
      add(:external_id, :text, null: false)
      add(:structure_id, references(:data_structures, on_delete: :nilify_all), null: true)
      add(:type, :string, null: false)
      add(:label, :map, null: false)
      add(:deleted_at, :utc_datetime_usec, null: true)
      timestamps(type: :utc_datetime_usec)
    end

    create table(:edges) do
      add(:unit_id, references(:units, on_delete: :delete_all), null: false)
      add(:start_id, references(:nodes, on_delete: :delete_all), null: false)
      add(:end_id, references(:nodes, on_delete: :delete_all), null: false)
      add(:type, :string, null: false)
      timestamps(type: :utc_datetime_usec)
    end

    create table(:units_nodes, primary_key: false) do
      add(:unit_id, references(:units, on_delete: :delete_all), null: false, primary_key: true)
      add(:node_id, references(:nodes, on_delete: :delete_all), null: false, primary_key: true)
      add(:deleted_at, :utc_datetime_usec, null: true)
    end

    create(unique_index(:units, [:name]))
    create(unique_index(:units_nodes, [:unit_id, :node_id]))
    create(unique_index(:nodes, [:external_id]))
    create(unique_index(:edges, [:unit_id, :start_id, :end_id]))
    create(index(:edges, [:start_id, :end_id]))
    create(index(:edges, [:end_id, :start_id]))
  end
end
