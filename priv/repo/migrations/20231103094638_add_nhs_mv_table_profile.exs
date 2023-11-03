defmodule TdDd.Repo.Migrations.AddNhsMvTableProfile do
  use Ecto.Migration

  def change do

    execute(
      """
      CREATE MATERIALIZED VIEW IF NOT EXISTS vm_table_profile_test as
      select tables.data_structure_id table_id, tables.table_name , columns.column_name, column_profiles.*,values->0 as key, values->1 as amount from
      (select data_structure_id, name table_name from (select *,RANK() OVER(PARTITION BY data_structure_id ORDER BY Version DESC) Rank from data_structure_versions) c where rank=1 and Type='Table') tables
      JOIN data_structures_hierarchy r ON (r.ancestor_ds_id = tables.data_structure_id and ancestor_level=1)
      JOIN (select id,data_structure_id,
      p.value::json->>'max' as max,
      p.value::json->>'min' as min,
      p.value::json->>'sum' as sum,
      p.value::json->>'mean' as mean,
      p.value::json->>'mode' as mode,
      p.value::json->>'range' as range,
      p.value::json->>'median' as median,
      p.value::json->>'entropy' as entropy,
      p.value::json->>'kurtosis' as kurtosis,
      p.value::json->>'skewness' as skewness,
      p.value::json->>'variance' as variance,
      p.value::json->>'null_count' as null_count,
      p.value::json->>'total_count' as total_count,
      p.value::json->>'zeros_count' as zeros_count,
      p.value::json->>'percentile_5' as percentile_5,
      p.value::json->>'percentile_25' as percentile_25,
      p.value::json->>'percentile_75' as percentile_75,
      p.value::json->>'percentile_95' as percentile_95,
      p.value::json->>'standard_deviation' as standard_deviation,
      p.value::json->>'interquartile_range' as interquartile_range,
      p.value::json->>'missing_values_count' as missing_values_count,
      p.value::json->>'distinct_values_count' as distinct_values_count,
      p.value::json->>'z_score_outliners_count' as z_score_outliners_count,
      p.value::json->>'median_absolute_deviation' as median_absolute_deviation,
      json_array_elements(
      CASE 
          WHEN p.value::json->>'most_frequent' = '' THEN ('[["No Data",'||total_count||']]')::json
          WHEN p.value::json->>'most_frequent' is null THEN ('[["No Data",'||total_count||']]')::json
          WHEN p.value::json->>'most_frequent' = '[]' THEN ('[["No Data",'||total_count||']]')::json
          ELSE (p.value::json->>'most_frequent')::json
      END)
      as values from profiles p
      ) column_profiles ON r.ds_id = column_profiles.data_structure_id
      JOIN (select data_structure_id, name column_name from (select *,RANK() OVER(PARTITION BY data_structure_id ORDER BY Version DESC) Rank from data_structure_versions) c where rank=1 and Type='Column') columns ON (columns.data_structure_id =r.ds_id )

      """,
      "DROP MATERIALIZED VIEW IF EXISTS vm_table_profile_test"
    )

    execute(
      """
      SELECT cron.schedule(
      'vm_table_profile_test',
      '*/5 * * * *',
      $CRON$ REFRESH MATERIALIZED VIEW public.vm_table_profile_test; $CRON$

      """,
      "SELECT cron.unschedule('vm_table_profile_test')"
    )

    execute(
      """
      UPDATE cron.job SET database = 'td_dd' WHERE jobid = (select jobid from cron.job where jobname  = 'vm_table_profile_test')

      """
    )
  end
end
