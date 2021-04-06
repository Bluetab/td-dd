defmodule TdDd.Repo.Migrations.DropDataFields do
  use Ecto.Migration

  def change do
    drop(table("versions_fields"))
    drop(table("data_fields"))
  end
end
