defmodule TdDq.Repo.Migrations.AddDynamicFormFields do
  use Ecto.Migration

  def change do
    alter table("rules") do
      add(:df_name, :string)
      add(:df_content, :map)
    end
  end
end
