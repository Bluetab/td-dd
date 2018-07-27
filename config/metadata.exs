use Mix.Config

config :td_dd, :metadata,
  data_structure_keys: ["system", "group", "name", "description", "type", "ou",
                        "lopd", "metadata", "domain_id"],
  data_field_keys: ["system", "group", "name", "field_name", "type", "description",
                    "nullable", "precision", "business_concept_id", "metadata"],
  data_structure_query:
  """
    INSERT INTO data_structures ("system", "group", "name", description, type, ou, lopd, metadata, last_change_at, last_change_by, inserted_at, updated_at, domain_id)
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $11, $10, $11, $11, $9)
    ON CONFLICT ("system", "group", "name")
    DO UPDATE SET type = $5, metadata = $8, last_change_at = $11, last_change_by = $10, updated_at = $11;
  """,
  data_field_query:
  """
    INSERT INTO data_fields (data_structure_id, name, type, description, nullable, precision, business_concept_id, metadata, last_change_at, last_change_by, inserted_at, updated_at)
    VALUES ((select id from data_structures where "system" = $1 and "group" = $2 and "name" = $3),
    $4, $5, $6, $7, $8, $9, $10, $12, $11, $12, $12)
    ON CONFLICT (data_structure_id, name)
    DO UPDATE SET name = $4, type = $5, nullable = $7, precision = $8, business_concept_id = $9, metadata = $10, last_change_at = $12, last_change_by = $11, updated_at = $12
  """,
  data_structure_modifiable_fields: ["description", "ou", "lopd"],
  data_field_modifiable_fields: ["description", "external_id"]
