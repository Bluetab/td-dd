use Mix.Config

config :td_dd, :metadata,
  data_structure_keys: ["system", "group", "name", "description", "type", "ou",
                        "lopd", "metadata", "domain_id"],
  data_field_keys: ["system", "group", "name", "field_name", "type", "description",
                    "nullable", "precision", "business_concept_id", "metadata"],
  data_structure_modifiable_fields: ["description", "ou", "lopd"],
  data_field_modifiable_fields: ["description"]
