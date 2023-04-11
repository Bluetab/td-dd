defmodule TdDd.Repo.Migrations.AddNhsIndices do
  use Ecto.Migration

  def change do
    create index("data_structure_versions", [:inserted_at])

    execute(
      """
      CREATE INDEX data_structure_versions_performance_startTime_index ON data_structure_versions USING btree (
        (metadata->'performance'->>'startTime'),
        (metadata->'pipeline_data'->>'process_uuid')
      )
      """,
      "DROP INDEX data_structure_versions_performance_startTime_index"
    )

    execute(
      """
      CREATE INDEX data_structure_versions_performance_currentTime_index ON data_structure_versions USING btree (
        (metadata->'performance'->>'currentTime'),
        (metadata->'pipeline_data'->>'process_uuid')
      )
      """,
      "DROP INDEX data_structure_versions_performance_currentTime_index"
    )
  end
end
