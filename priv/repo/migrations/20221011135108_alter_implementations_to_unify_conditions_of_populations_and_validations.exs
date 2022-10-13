defmodule TdDd.Repo.Migrations.AlterImplementationsToUnifyConditionsOfPopulationsAndValidations do
  use Ecto.Migration

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
    execute(
      refactor_condition("validations_set", "validations", "conditions"),
      refactor_condition("validations_set", "conditions", "validations")
    )

    execute(
      refactor_condition("populations", "population", "conditions"),
      refactor_condition("populations", "conditions", "population")
    )
  end
end
