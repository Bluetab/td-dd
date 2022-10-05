defmodule TdDd.Repo.Migrations.CreateFunctions do
  use Ecto.Migration

  def change do
    create table("functions") do
      add :name, :string, null: false
      add :args, :map, null: false
      add :group, :string
      add :scope, :string
      add :return_type, :string, null: false
      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index("functions", [:name, :args], where: ~s(scope is null and "group" is null))
    create unique_index("functions", [:name, :args, :group], where: "scope is null")
    create unique_index("functions", [:name, :args, :scope], where: ~s("group" is null))
    create unique_index("functions", [:name, :args, :group, :scope])

    # When Postgres 15+ is required, the partial indices can be replaced as follows:
    # create unique_index("functions", [:name, :args, :group, :scope], nulls_distinct: false)
  end
end
