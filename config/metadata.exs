use Mix.Config

config :td_dd, :metadata,
  structure_import_schema: %{
    description: :string,
    domain_id: :integer,
    external_id: :string,
    group: :string,
    metadata: :map,
    name: :string,
    ou: :string,
    system_id: :integer,
    type: :string,
    version: :integer
  },
  structure_import_required: [:name, :system_id, :group, :type],
  field_import_schema: %{
    business_concept_id: :string,
    description: :string,
    external_id: :string,
    field_name: :string,
    group: :string,
    metadata: :map,
    name: :string,
    nullable: :boolean,
    precision: :string,
    system_id: :integer,
    type: :string,
    version: :integer
  },
  field_import_required: [:system_id, :group, :name, :field_name, :type],
  relation_import_schema: %{
    system_id: :integer,
    parent_group: :string,
    parent_external_id: :string,
    parent_name: :string,
    child_group: :string,
    child_external_id: :string,
    child_name: :string
  },
  relation_import_required: [:system_id, :parent_group, :child_group]
