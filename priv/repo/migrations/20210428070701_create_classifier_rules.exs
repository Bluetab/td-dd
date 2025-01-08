defmodule TdDd.Repo.Migrations.CreateClassifierRules do
  use Ecto.Migration

  def change do
    create table("classifier_rules") do
      add :classifier_id, references("classifiers", on_delete: :delete_all), null: false
      add :priority, :integer, null: false
      add :path, {:array, :string}, null: false
      add :class, :string, null: false
      add :regex, :string
      add :values, {:array, :string}

      timestamps(type: :utc_datetime_usec)
    end

    create constraint("classifier_rules", :values_xor_regex,
             check: "num_nulls(regex, values) = 1"
           )
  end
end
