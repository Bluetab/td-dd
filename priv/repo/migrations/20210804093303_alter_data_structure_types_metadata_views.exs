defmodule TdDd.Repo.Migrations.AlterDataStructureTypesMetadataViews do
  use Ecto.Migration

  def change do
    alter table("data_structure_types") do
      add :metadata_views, :map
    end

    execute(
      """
      update data_structure_types
      set metadata_views = jsonb_build_array(jsonb_build_object('name', 'default', 'fields', metadata_fields->'values'))
      where metadata_fields is not null
      """,
      """
      update data_structure_types
      set metadata_fields = json_build_object('values', metadata_views#>'{0,fields}')
      where jsonb_array_length(metadata_views) >= 1
      """
    )

    execute(
      """
      update data_structure_types
      set metadata_views = jsonb_set(metadata_views, '{0,fields}', '[]'::jsonb, false)
      where metadata_views#>'{0,fields}' = '"*"'
      """,
      """
      update data_structure_types
      set metadata_views = jsonb_set(metadata_views, '{0,fields}', '"*"', false)
      where metadata_views#>'{0,fields}' = '[]'::jsonb
      """
    )

    alter table("data_structure_types") do
      remove :metadata_fields, :map
    end
  end
end
