defmodule TdDd.Repo.Migrations.CreateClassifierFilters do
  use Ecto.Migration

  def change do
    create table("classifier_filters") do
      add :classifier_id, references("classifiers", on_delete: :delete_all), null: false
      add :property, :string, null: false
      add :regex, :string
      add :values, {:array, :string}

      timestamps(type: :utc_datetime_usec)
    end

    create(
      constraint("classifier_filters", :values_xor_regex, check: "num_nulls(regex, values) = 1")
    )
  end
end
