import Config

config :td_dd, :metadata,
  structure_import_schema: %{
    class: :string,
    description: :string,
    domain_ids: {:array, :integer},
    external_id: :string,
    group: :string,
    metadata: :map,
    mutable_metadata: :map,
    name: :string,
    system_id: :integer,
    type: :string
  },
  structure_import_required: [:name, :external_id, :system_id, :group, :type],
  structure_import_boolean: ["m:nullable"],
  field_import_schema: %{
    description: :string,
    external_id: :string,
    field_external_id: :string,
    field_name: :string,
    metadata: :map,
    mutable_metadata: :map,
    nullable: :boolean,
    precision: :string,
    type: :string
  },
  field_import_required: [:external_id, :field_name, :type],
  relation_import_schema: %{
    parent_external_id: :string,
    child_external_id: :string,
    relation_type_name: :string
  },
  relation_import_required: [:parent_external_id, :child_external_id]
