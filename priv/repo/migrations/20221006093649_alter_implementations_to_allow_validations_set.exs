defmodule TdDd.Repo.Migrations.AlterImplementationsToAllowValidationsSet do
  use Ecto.Migration

  def change do
    alter table("rule_implementations") do
      add(:validations_set, {:array, :map}, default: [])
    end

    execute(
      """
        update rule_implementations set validations_set = array[json_build_object('validations', array_to_json(validations))]
        where array_length(validations, 1) > 0;
      """,
      """
      update rule_implementations ri set validations = first_validations
      from (
        select id, array_agg(first_validations) as first_validations
        from rule_implementations
        cross join lateral json_array_elements(validations_set[1]::json#>'{validations}') as first_validations
        where array_length(validations_set, 1) > 0
        GROUP BY id
      ) as t
      where t.id = ri.id
      """
    )

    alter table("rule_implementations") do
      remove(:validations, {:array, :map}, default: [])
    end
  end
end
