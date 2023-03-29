defmodule TdDd.Factory do
  @moduledoc """
  An `ExMachina` factory for data quality tests.
  """

  use ExMachina.Ecto, repo: TdDd.Repo
  use TdDfLib.TemplateFactory

  alias TdCx.Configurations.Configuration
  alias TdCx.Events.Event
  alias TdCx.Jobs.Job
  alias TdCx.Sources.Source
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureLink
  alias TdDd.DataStructures.DataStructureRelation
  alias TdDd.DataStructures.DataStructureType
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.Label
  alias TdDd.DataStructures.MetadataField
  alias TdDd.DataStructures.MetadataView
  alias TdDd.DataStructures.RelationType
  alias TdDd.DataStructures.StructureMetadata
  alias TdDd.DataStructures.StructureNote
  alias TdDd.DataStructures.Tags.Tag
  alias TdDd.Lineage.Units
  alias TdDd.Profiles.Profile
  alias TdDd.UserSearchFilters.UserSearchFilter
  alias TdDq.Remediations.Remediation

  def claims_factory(attrs), do: do_claims(attrs, Truedat.Auth.Claims)

  defp do_claims(attrs, module) do
    module
    |> Kernel.struct(
      user_id: sequence(:user_id, & &1),
      user_name: sequence("user_name"),
      role: "admin",
      jti: sequence("jti"),
      exp: DateTime.add(DateTime.utc_now(), 10)
    )
    |> merge_attributes(attrs)
  end

  def data_structure_factory(attrs) do
    attrs = default_assoc(attrs, :system_id, :system)

    %DataStructure{
      confidential: false,
      external_id: sequence("ds_external_id"),
      last_change_by: 0
    }
    |> merge_attributes(attrs)
  end

  def data_structure_version_factory(attrs) do
    {structure_attrs, attrs} = Map.split(attrs, [:domain_ids, :alias])

    attrs =
      default_assoc(attrs, :data_structure_id, :data_structure, :data_structure, structure_attrs)

    %DataStructureVersion{
      description: sequence("data_structure_version_description"),
      group: sequence("data_structure_version_group"),
      name: sequence("data_structure_version_name"),
      metadata: %{"description" => "some description"},
      version: 0,
      type: "Table"
    }
    |> merge_attributes(attrs)
  end

  def structure_note_factory(attrs) do
    attrs = default_assoc(attrs, :data_structure_id, :data_structure)

    %StructureNote{
      status: :draft,
      version: 1,
      df_content: %{}
    }
    |> merge_attributes(attrs)
  end

  def rule_factory do
    %TdDq.Rules.Rule{
      business_concept_id: sequence(:business_concept_id, & &1),
      domain_id: sequence(:domain_id, &"#{&1}"),
      description: %{"document" => "Rule Description"},
      name: sequence("rule_name"),
      active: false,
      version: 1,
      updated_by: sequence(:updated_by, & &1)
    }
  end

  def raw_implementation_factory(attrs) do
    {content_attrs, attrs} = Map.split(attrs, [:source_id])

    attrs =
      attrs
      |> default_assoc(:rule_id, :rule)
      |> merge_attrs_with_ref()

    %TdDq.Implementations.Implementation{
      implementation_key: sequence("ri"),
      implementation_type: "raw",
      goal: 30,
      minimum: 12,
      result_type: "percentage",
      raw_content: build(:raw_content, content_attrs),
      deleted_at: nil,
      version: 1,
      status: "draft"
    }
    |> merge_attributes(attrs)
  end

  def raw_content_factory(attrs) do
    %TdDq.Implementations.RawContent{
      dataset: "clientes c join address a on c.address_id=a.id",
      population: "a.country = 'SPAIN'",
      source_id: 1,
      database: "raw_database",
      validations: "a.city is null"
    }
    |> merge_attributes(attrs)
  end

  def implementation_factory(attrs) do
    attrs =
      attrs
      |> default_assoc(:rule_id, :rule)
      |> merge_attrs_with_ref()

    %TdDq.Implementations.Implementation{
      implementation_key: sequence("implementation_key"),
      implementation_type: "default",
      goal: 30,
      minimum: 12,
      domain_id: 2,
      dataset: build(:dataset),
      populations: build(:populations),
      validation: build(:validation),
      segments: [build(:segments_row)],
      version: 1,
      status: "draft"
    }
    |> merge_attributes(attrs)
  end

  def basic_implementation_factory(attrs) do
    attrs =
      attrs
      |> default_assoc(:rule_id, :rule)
      |> merge_attrs_with_ref()

    %TdDq.Implementations.Implementation{
      implementation_key: sequence("implementation_key"),
      implementation_type: "basic",
      goal: 30,
      minimum: 12,
      domain_id: 2,
      version: 1,
      status: "draft"
    }
    |> merge_attributes(attrs)
  end

  defp merge_attrs_with_ref(attrs) do
    id = Map.get(attrs, :id, System.unique_integer([:positive]))

    with_ref_attrs = %{
      id: id,
      implementation_ref: Map.get(attrs, :implementation_ref, id)
    }

    attrs
    |> merge_attributes(with_ref_attrs)
  end

  def ruleless_implementation_factory(attrs) do
    attrs = merge_attrs_with_ref(attrs)

    %TdDq.Implementations.Implementation{
      implementation_key: sequence("implementation_key"),
      implementation_type: "default",
      goal: 30,
      minimum: 12,
      domain_id: 2,
      dataset: build(:dataset),
      populations: build(:populations),
      validation: build(:validation),
      version: 1,
      status: "draft"
    }
    |> merge_attributes(attrs)
  end

  def basic_ruleless_implementation_factory(attrs) do
    attrs = merge_attrs_with_ref(attrs)

    %TdDq.Implementations.Implementation{
      implementation_key: sequence("implementation_key"),
      implementation_type: "basic",
      goal: 30,
      minimum: 12,
      domain_id: 2,
      version: 1,
      status: "draft"
    }
    |> merge_attributes(attrs)
  end

  def implementation_structure_factory(attrs) do
    attrs =
      attrs
      |> default_assoc(:data_structure_id, :data_structure)
      |> default_assoc(:implementation_id, :implementation)

    %TdDq.Implementations.ImplementationStructure{
      type: :dataset
    }
    |> merge_attributes(attrs)
  end

  def data_structure_relation_factory(attrs) do
    attrs =
      attrs
      |> default_assoc(:child_id, :child, :data_structure_version)
      |> default_assoc(:parent_id, :parent, :data_structure_version)
      |> default_assoc(:relation_type_id, :relation_type)

    %DataStructureRelation{}
    |> merge_attributes(attrs)
  end

  def tag_factory do
    %Tag{
      name: sequence("tag_name"),
      description: sequence("tag_description")
    }
  end

  def data_structure_type_factory do
    %DataStructureType{
      name: sequence("structure_type_name"),
      template_id: sequence(:template_id, & &1),
      translation: sequence("translation"),
      metadata_views: [%MetadataView{name: "foo", fields: ["bar"]}]
    }
  end

  def metadata_view_factory do
    %MetadataView{
      name: sequence("metadata_view_name"),
      fields: [sequence("metadata_field")]
    }
  end

  def metadata_field_factory(attrs) do
    attrs = default_assoc(attrs, :data_structure_type_id, :data_structure_type)

    %MetadataField{
      name: sequence("metadata_field_name")
    }
    |> merge_attributes(attrs)
  end

  def system_factory do
    %TdDd.Systems.System{
      name: sequence("system_name"),
      external_id: sequence("system_external_id")
    }
  end

  def relation_type_factory do
    %RelationType{
      name: sequence("relation_type_name")
    }
  end

  def profile_factory(attrs) do
    attrs = default_assoc(attrs, :data_structure_id, :data_structure)

    %Profile{value: %{"foo" => "bar"}}
    |> merge_attributes(attrs)
  end

  def structure_metadata_factory(attrs) do
    attrs = default_assoc(attrs, :data_structure_id, :data_structure)

    %StructureMetadata{
      fields: %{"foo" => "bar"},
      version: 0
    }
    |> merge_attributes(attrs)
  end

  def unit_factory do
    %Units.Unit{name: sequence("unit")}
  end

  def unit_event_factory do
    %Units.Event{event: "EventType", inserted_at: DateTime.utc_now()}
  end

  def node_factory do
    %Units.Node{external_id: sequence("node_external_id"), type: "Resource"}
  end

  def edge_factory do
    %Units.Edge{type: "DEPENDS"}
  end

  def hierarchy_factory(attrs) do
    %{
      id: System.unique_integer([:positive]),
      name: sequence("family_"),
      description: sequence("description_"),
      nodes: [],
      updated_at: DateTime.utc_now()
    }
    |> merge_attributes(attrs)
  end

  def hierarchy_node_factory(attrs) do
    name = sequence("node_")
    hierarchy_id = System.unique_integer([:positive])
    node_id = System.unique_integer([:positive])

    %{
      node_id: node_id,
      hierarchy_id: hierarchy_id,
      parent_id: System.unique_integer([:positive]),
      name: name,
      description: sequence("description_"),
      path: "/#{name}",
      key: "#{hierarchy_id}_#{node_id}"
    }
    |> merge_attributes(attrs)
  end

  def user_search_filter_factory do
    %UserSearchFilter{
      id: sequence(:user_search_filter, & &1),
      name: sequence("filter_name"),
      filters: %{"country" => ["Sp"]},
      user_id: sequence(:user_id, & &1),
      scope:
        sequence(:user_search_filter_scope, ["data_structure", "rule", "rule_implementation"]),
      is_global: false
    }
  end

  def domain_factory do
    %{
      name: sequence("domain_name"),
      id: System.unique_integer([:positive]),
      external_id: sequence("domain_external_id"),
      updated_at: DateTime.utc_now()
    }
  end

  def concept_factory do
    %{
      id: System.unique_integer([:positive]),
      name: sequence("concept_name")
    }
  end

  def profile_execution_factory do
    %TdDd.Executions.ProfileExecution{
      profile_group: build(:profile_execution_group),
      data_structure: build(:data_structure)
    }
  end

  def profile_execution_group_factory do
    %TdDd.Executions.ProfileGroup{
      created_by_id: 0
    }
  end

  def profile_event_factory do
    %TdDd.Executions.ProfileEvent{
      type: "PENDING"
    }
  end

  def source_factory do
    %Source{
      config: %{},
      external_id: sequence("source_external_id"),
      secrets_key: sequence("source_secrets_key"),
      type: sequence("source_type")
    }
  end

  def job_factory(attrs) do
    attrs = default_assoc(attrs, :source_id, :source)

    %Job{type: sequence(:job_type, ["Metadata", "DQ", "Profile"])}
    |> merge_attributes(attrs)
  end

  def event_factory(attrs) do
    attrs = default_assoc(attrs, :job_id, :job)

    %Event{
      type: sequence("event_type"),
      message: sequence("event_message")
    }
    |> merge_attributes(attrs)
  end

  def remediation_factory(attrs) do
    attrs = default_assoc(attrs, :rule_result_id, :rule_result)

    %Remediation{
      df_name: "template_name",
      df_content: %{}
    }
    |> merge_attributes(attrs)
  end

  def configuration_factory do
    %Configuration{
      type: "config",
      content: %{},
      external_id: sequence("external_id")
    }
  end

  def dataset_factory(_attrs) do
    [
      build(:dataset_row),
      build(:dataset_row, clauses: [build(:dataset_clause)], join_type: "inner")
    ]
  end

  def dataset_row_factory do
    %TdDq.Implementations.DatasetRow{
      structure: build(:dataset_structure)
    }
  end

  def dataset_structure_factory do
    %TdDq.Implementations.Structure{
      id: sequence(:dataset_structure_id, &(&1 + 14_080))
    }
  end

  def dataset_clause_factory do
    %TdDq.Implementations.JoinClause{
      left: build(:dataset_structure),
      right: build(:dataset_structure)
    }
  end

  def populations_factory(_attrs) do
    [
      %TdDq.Implementations.Conditions{
        conditions: [build(:condition_row)]
      }
    ]
  end

  def validation_factory(_attrs) do
    [
      %TdDq.Implementations.Conditions{
        conditions: [build(:condition_row)]
      }
    ]
  end

  def segments_row_factory do
    %TdDq.Implementations.SegmentsRow{structure: build(:dataset_structure)}
  end

  def segment_result_factory do
    %TdDq.Rules.RuleResult{
      result: "#{Decimal.round(50, 2)}",
      date: "#{DateTime.utc_now()}"
    }
  end

  def condition_row_factory do
    %TdDq.Implementations.ConditionRow{
      value: [%{"raw" => 8}],
      operator: build(:operator),
      structure: build(:dataset_structure),
      population: []
    }
  end

  def operator_factory do
    %TdDq.Implementations.Operator{name: "eq", value_type: "number"}
  end

  def modifier_factory do
    %TdDq.Implementations.Modifier{name: "cast_as_date", params: %{"format" => "YYYYMMDD"}}
  end

  def rule_result_factory do
    %TdDq.Rules.RuleResult{
      result: "#{Decimal.round(50, 2)}",
      date: "#{DateTime.utc_now()}"
    }
  end

  def rule_result_record_factory(attrs) do
    %{
      implementation_key: sequence("ri"),
      date: "2020-02-02T00:00:00Z",
      result: "0",
      records: "",
      errors: ""
    }
    |> merge_attributes(attrs)
    |> Enum.reject(fn {_k, v} -> v == "" end)
    |> Map.new()
  end

  def implementation_result_record_factory(attrs) do
    %{
      date: "2020-02-02T00:00:00Z",
      records: nil,
      errors: nil
    }
    |> merge_attributes(attrs)
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  def execution_factory(attrs) do
    {impl_attrs, attrs} = Map.split(attrs, [:domain_id, :implementation_ref])

    attrs =
      attrs
      |> default_assoc(:group_id, :group, :execution_group)
      |> default_assoc(:implementation_id, :implementation, :implementation, impl_attrs)

    %TdDq.Executions.Execution{}
    |> merge_attributes(attrs)
  end

  def execution_group_factory do
    %TdDq.Executions.Group{
      created_by_id: 0
    }
  end

  def quality_event_factory(attrs) do
    %TdDq.Events.QualityEvent{
      type: "PENDING"
    }
    |> merge_attributes(attrs)
  end

  def structure_tag_factory(attrs) do
    attrs =
      attrs
      |> default_assoc(:data_structure_id, :data_structure)
      |> default_assoc(:tag_id, :tag)

    %TdDd.DataStructures.Tags.StructureTag{
      comment: sequence("foo")
    }
    |> merge_attributes(attrs)
  end

  def csv_bulk_update_event_factory do
    %TdDd.DataStructures.CsvBulkUpdateEvent{
      csv_hash: "47D90FDF1AD967BD7DBBDAE28664278E",
      inserted_at: "2022-04-24T11:08:18.215905Z",
      message: nil,
      response: %{errors: [], ids: [1, 2]},
      status: "COMPLETED",
      task_reference: "0.262460172.3388211201.119663",
      user_id: 467,
      filename: sequence("foo_file")
    }
  end

  def classifier_factory(attrs) do
    attrs = default_assoc(attrs, :system_id, :system)

    %TdDd.Classifiers.Classifier{
      name: sequence("classification")
    }
    |> merge_attributes(attrs)
  end

  def grant_factory(attrs) do
    attrs = default_assoc(attrs, :data_structure_id, :data_structure)

    %TdDd.Grants.Grant{
      source_user_name: sequence("grant_source_user_name"),
      detail: %{"foo" => "bar"},
      start_date: "2020-01-02",
      end_date: "2021-02-03"
    }
    |> merge_attributes(attrs)
  end

  def grant_request_group_factory(attrs) do
    user_id = sequence(:user_id, &"#{&1}")

    %TdDd.Grants.GrantRequestGroup{
      id: sequence(:grant_request_group, &(&1 + 1_080)),
      user_id: user_id,
      created_by_id: user_id,
      type: nil
    }
    |> merge_attributes(attrs)
  end

  def grant_request_factory(attrs) do
    attrs =
      attrs
      |> default_assoc(:data_structure_id, :data_structure)
      |> default_assoc(:group_id, :group, :grant_request_group)

    %TdDd.Grants.GrantRequest{
      filters: %{"grant_filters" => "bar"},
      metadata: %{"grant_meta" => "bar"},
      domain_ids: [123]
    }
    |> merge_attributes(attrs)
  end

  def grant_request_status_factory(attrs) do
    attrs = default_assoc(attrs, :grant_request_id, :grant_request)

    %TdDd.Grants.GrantRequestStatus{
      status: "pending"
    }
    |> merge_attributes(attrs)
  end

  def grant_request_approval_factory(attrs) do
    attrs = default_assoc(attrs, :grant_request_id, :grant_request)

    %TdDd.Grants.GrantRequestApproval{
      user_id: sequence(:user_id, &"#{&1}"),
      role: "role1",
      is_rejection: false
    }
    |> merge_attributes(attrs)
  end

  def approval_rule_factory do
    %TdDd.Grants.ApprovalRule{
      name: sequence("rule_name"),
      user_id: sequence(:user_id, &"#{&1}"),
      role: "role1",
      domain_ids: [123],
      action: "approve",
      conditions: [build(:approval_rule_condition)]
    }
  end

  def approval_rule_condition_factory do
    %TdDd.Grants.Condition{field: "foo", operator: "is", values: ["bar"]}
  end

  def regex_filter_factory(attrs) do
    attrs = default_assoc(attrs, :classifier_id, :classifier)

    %TdDd.Classifiers.Filter{
      path: ["type"],
      regex: "foo"
    }
    |> merge_attributes(attrs)
  end

  def values_filter_factory(attrs) do
    attrs = default_assoc(attrs, :classifier_id, :classifier)

    %TdDd.Classifiers.Filter{
      path: ["type"],
      values: [sequence("value")]
    }
    |> merge_attributes(attrs)
  end

  def regex_rule_factory(attrs) do
    attrs = default_assoc(attrs, :classifier_id, :classifier)

    %TdDd.Classifiers.Rule{
      class: sequence("class"),
      path: ["metadata", "foo", "bar"],
      regex: "foo"
    }
    |> merge_attributes(attrs)
  end

  def values_rule_factory(attrs) do
    attrs = default_assoc(attrs, :classifier_id, :classifier)

    %TdDd.Classifiers.Rule{
      class: sequence("class"),
      path: ["metadata", "foo", "bar"],
      values: ["foo"]
    }
    |> merge_attributes(attrs)
  end

  def structure_classification_factory(attrs) do
    attrs =
      attrs
      |> default_assoc(:rule_id, :rule, :regex_rule)
      |> default_assoc(:classifier_id, :classifier)
      |> default_assoc(:data_structure_version_id, :data_structure_version)

    %TdDd.DataStructures.Classification{
      class: sequence("class_value"),
      name: sequence("class_name")
    }
    |> merge_attributes(attrs)
  end

  def lineage_event_factory do
    %TdDd.Lineage.LineageEvent{
      user_id: "438",
      graph_data: "TERADESA.BASILEAII.HIST_PROA_MOROSIDAD.ANTICIPOCAPITALIMPAGADO",
      task_reference: "0.2996324945.3784572938.100946",
      node: "nonode@nohost"
    }
  end

  def user_factory do
    %{
      id: System.unique_integer([:positive]),
      role: "user",
      user_name: sequence("user_name"),
      full_name: sequence("full_name"),
      external_id: sequence("user_external_id"),
      email: sequence("email") <> "@example.com"
    }
  end

  def reference_dataset_factory do
    %TdDd.ReferenceData.Dataset{
      name: sequence("dataset_name"),
      headers: ["FOO", "BAR", "BAZ"],
      rows: [["foo1", "bar1", "baz1"], ["foo2", "bar2", "baz2"]]
    }
  end

  def function_factory do
    %TdDq.Functions.Function{
      name: sequence("function_name"),
      return_type: sequence(:argument_type, ["string", "number", "boolean"]),
      args: [build(:argument)]
    }
  end

  def argument_factory do
    %TdDq.Functions.Argument{
      type: sequence(:argument_type, ["string", "number", "any"])
    }
  end

  def data_structure_link_factory(attrs) do
    attrs =
      default_assoc(attrs, :source_id, :source)
      |> default_assoc(:target_id, :target)
      |> default_assoc(:labels, :labels)

    %DataStructureLink{}
    |> merge_attributes(attrs)
  end

  def label_factory do
    %Label{name: sequence("label_name")}
  end

  def access_factory(attrs) do
    attrs = default_assoc(attrs, :data_structure_external_id, :data_structure)

    %TdDd.Access{
      source_user_name: sequence("access_source_user_name"),
      details: %{}
    }
    |> merge_attributes(attrs)
  end

  defp default_assoc(attrs, id_key, key, build_key \\ nil, build_params \\ %{}) do
    if Enum.any?([key, id_key], &Map.has_key?(attrs, &1)) do
      attrs
    else
      build_key = if build_key, do: build_key, else: key
      Map.put(attrs, key, build(build_key, build_params))
    end
  end
end
