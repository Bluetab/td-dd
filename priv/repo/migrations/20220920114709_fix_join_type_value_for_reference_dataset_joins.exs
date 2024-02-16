defmodule TdDd.Repo.Migrations.FixJoinTypeValueForReferenceDatasetJoins do
  use Ecto.Migration

  def change do
    execute(
      """
        WITH datasets_to_update AS (
          SELECT
            id,
            array_agg(
              CASE WHEN elems ->> 'join_type' = 'reference_dataset'
              THEN jsonb_set(elems, '{join_type}', '"inner"')
              ELSE elems END
            ) dataset,
            bool_or(
              elems ->> 'join_type' = 'reference_dataset'
            ) need_update
          FROM
            rule_implementations,
            unnest(dataset) elems
          group by
            id
        )
        UPDATE
          rule_implementations
        set
          dataset = datasets_to_update.dataset :: jsonb[]
        FROM
          datasets_to_update
        WHERE
          rule_implementations.id = datasets_to_update.id
          and datasets_to_update.need_update;
      """,
      """
        WITH datasets_to_update AS (
          SELECT
            id,
            array_agg(
              CASE WHEN elems -> 'structure' ->> 'type' = 'reference_dataset' THEN jsonb_set(
                elems, '{join_type}', '"reference_dataset"'
              ) ELSE elems END
            ) dataset,
            bool_or(
              elems -> 'structure' ->> 'type' = 'reference_dataset'
            ) need_update
          FROM
            rule_implementations,
            unnest(dataset) elems
          group by
            id
        )
        UPDATE
          rule_implementations
        set
          dataset = datasets_to_update.dataset :: jsonb[]
        FROM
          datasets_to_update
        WHERE
          rule_implementations.id = datasets_to_update.id
          and datasets_to_update.need_update;
      """
    )
  end
end
