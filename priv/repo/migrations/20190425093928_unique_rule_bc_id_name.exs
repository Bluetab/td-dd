defmodule TdDq.Repo.Migrations.UniqueRuleBcIdName do
  use Ecto.Migration

  def change do
    create(
      unique_index("rules", [:business_concept_id, :name],
        where: "business_concept_id IS NOT NULL AND deleted_at IS NULL"
      )
    )

    create(
      unique_index("rules", [:name], where: "business_concept_id IS NULL AND deleted_at IS NULL")
    )
  end
end
