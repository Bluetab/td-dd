defmodule TdDd.Repo.Migrations.CreateAccesses do
  use Ecto.Migration

  def change do
    create table("accesses") do
      add(:user_id, :bigint)

      add(
        :data_structure_external_id,
        references("data_structures", column: :external_id, type: :string, on_delete: :nothing)
      )

      add(:source_user_name, :string)
      add(:details, :map)
      add(:accessed_at, :utc_datetime, null: false)

      timestamps(type: :utc_datetime_usec)
    end

    create(
      unique_index("accesses", [:data_structure_external_id, :source_user_name, :accessed_at])
    )
  end
end
