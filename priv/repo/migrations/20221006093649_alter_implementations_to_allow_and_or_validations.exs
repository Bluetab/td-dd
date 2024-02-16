defmodule TdDd.Repo.Migrations.AlterImplementationsToAllowAndOrValidations do
  use Ecto.Migration

  @moduledoc """
  Migrate populations and validations to use Conditions schema
  """

  defp refactor_condition(column_name, from_key, to_key) do
    """
    WITH conditions_to_update AS (
      SELECT
        id,
        array_agg(
          CASE WHEN conditions ? '#{from_key}'
          THEN conditions - '#{from_key}' || jsonb_build_object('#{to_key}', conditions ->'#{from_key}')
          ELSE conditions END
        ) #{column_name},
        bool_or(
          conditions ? '#{from_key}'
        ) need_update
      FROM
        rule_implementations,
        unnest(#{column_name}) conditions
      group by
        id
    )
    UPDATE
      rule_implementations
    set
      #{column_name} = conditions_to_update.#{column_name} :: jsonb[]
    FROM
      conditions_to_update
    WHERE
      rule_implementations.id = conditions_to_update.id
      and conditions_to_update.need_update;
    """
  end

  def change do
    alter table("rule_implementations") do
      add(:validation, {:array, :map}, default: [])
    end

    execute(
      """
        update rule_implementations set validation = array[json_build_object('conditions', array_to_json(validations))]
        where array_length(validations, 1) > 0;
      """,
      """
      update rule_implementations ri set validations = first_validations
      from (
        select id, array_agg(first_validations) as first_validations
        from rule_implementations
        cross join lateral json_array_elements(validation[1]::json#>'{conditions}') as first_validations
        where array_length(validation, 1) > 0
        GROUP BY id
      ) as t
      where t.id = ri.id
      """
    )

    alter table("rule_implementations") do
      remove(:validations, {:array, :map}, default: [])
    end

    execute(
      refactor_condition("populations", "population", "conditions"),
      refactor_condition("populations", "conditions", "population")
    )
  end
end
