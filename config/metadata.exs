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
    system: :string,
    type: :string,
    version: :integer
  },
  structure_import_required: [:name, :system, :group, :type],
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
    system: :string,
    type: :string,
    version: :integer
  },
  field_import_required: [:name, :system, :group, :field_name, :type],
  relation_import_schema: %{
    system: :string,
    parent_group: :string,
    parent_external_id: :string,
    parent_name: :string,
    child_group: :string,
    child_external_id: :string,
    child_name: :string
  },
  relation_import_required: [:parent_group, :system, :child_group]
