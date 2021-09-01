defmodule TdDd.Repo.Migrations.AlterRulesBusinessConceptId do
  use Ecto.Migration

  def change do
    drop unique_index("rules", [:business_concept_id, :name],
           where: "business_concept_id IS NOT NULL AND deleted_at IS NULL"
         )

    drop unique_index("rules", [:name],
           where: "business_concept_id IS NULL AND deleted_at IS NULL"
         )

    rename table("rules"), :business_concept_id, to: :_bc_id_

    alter table("rules") do
      add(:business_concept_id, :integer)
    end

    execute(
      "update rules set business_concept_id = _bc_id_::integer",
      "update rules set _bc_id_ = business_concept_id::text"
    )

    alter table("rules") do
      remove(:_bc_id_, :string)
    end

    create unique_index("rules", [:business_concept_id, :name],
             where: "business_concept_id IS NOT NULL AND deleted_at IS NULL"
           )

    create unique_index("rules", [:name],
             where: "business_concept_id IS NULL AND deleted_at IS NULL"
           )
  end
end
