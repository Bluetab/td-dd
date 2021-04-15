defmodule TdDq.Repo.Migrations.AddDynamicFormFieldsImplementation do
  use Ecto.Migration

  def change do
    alter table("rule_implementations") do
      add(:df_name, :string)
      add(:df_content, :map)
    end
  end
end
