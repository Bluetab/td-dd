defmodule TdDq.Repo.Migrations.MigratePrincipleAndTagToContent do
  use Ecto.Migration

  def change do
    execute """
      UPDATE rules 
      SET 
        df_content = CONCAT('{"principle": "' , r.principle ->> 'name' , '", "tags": [' , l.tags , '] }' )::jsonb,
        df_name = 'dq_default_template'
      FROM rules r, LATERAL (
        SELECT string_agg( CONCAT('"', d.elem ->> 'name', '"'), ',') as tags	
        FROM jsonb_array_elements(r.tag->'tags') AS d(elem)
      ) l
      WHERE rules.id = r.id
    """

    alter table("rules") do
      remove :principle
      remove :tag
    end
  end
end
