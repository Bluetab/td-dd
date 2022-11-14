defmodule TdDd.Repo.Migrations.CreateLabelsAndDataStructureLinksLabels do
  use Ecto.Migration

  def change do
    create table(:labels) do
      add(:name, :string)

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:labels, [:name])

    create table(:data_structure_links_labels, primary_key: false) do
      add(
        :data_structure_link_id,
        references(:data_structures_links, on_delete: :delete_all, on_update: :update_all),
        primary_key: true
      )

      add(:label_id, references(:labels), primary_key: true)
    end
  end
end
