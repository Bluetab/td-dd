defmodule TdBg.Repo.Migrations.UpdateTemplateContentsFormat do
  use Ecto.Migration

  def change do
    do_changes("grant_requests", "metadata")
    do_changes("configurations", "content")
    do_changes("sources", "config")
    do_changes("structure_notes", "df_content")
    do_changes("systems", "df_content")
    do_changes("rule_implementations", "df_content")
    do_changes("remediations", "df_content")
    do_changes("rules", "df_content")
  end

  defp do_changes(table, column) do
    execute(
      """
      UPDATE
      #{table}
      SET #{column} = (
          SELECT jsonb_object_agg(key, jsonb_build_object('origin', 'user', 'value', value))
          FROM jsonb_each(#{column})
      ) WHERE #{column} != '{}' and #{column} IS NOT NULL;
      """,
      """
      UPDATE
      #{table}
      SET #{column} = (
        SELECT jsonb_object_agg(KEY, VALUE->'value')
          FROM jsonb_each(#{column})
      ) WHERE #{column} != '{}' AND #{column} IS NOT NULL;
      """
    )
  end
end
