use Mix.Config

config :td_dd, :metadata,
  data_structure_keys: [
    "system",
    "group",
    "name",
    "description",
    "type",
    "ou",
    "metadata",
    "domain_id",
    "version"
  ],
  data_field_keys: [
    "system",
    "group",
    "name",
    "field_name",
    "type",
    "description",
    "nullable",
    "precision",
    "business_concept_id",
    "metadata",
    "version"
  ],
  data_structure_relation_keys: [
    "system",
    "parent_group",
    "parent_name",
    "child_group",
    "child_name"
  ],
  data_structure_modifiable_fields: [
    "description",
    "confidential",
    "df_name",
    "df_content"
  ],
  data_field_modifiable_fields: ["description"]
