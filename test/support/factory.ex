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
  alias TdDd.DataStructures.DataStructureRelation
  alias TdDd.DataStructures.DataStructureTag
  alias TdDd.DataStructures.DataStructureType
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.Profile
  alias TdDd.DataStructures.RelationType
  alias TdDd.DataStructures.StructureMetadata
  alias TdDd.DataStructures.StructureNote
  alias TdDd.Lineage.Units
  alias TdDd.Systems.System
  alias TdDd.UserSearchFilters.UserSearchFilter

  def claims_factory(attrs), do: do_claims(attrs, TdDd.Auth.Claims)

  def cx_claims_factory(attrs), do: do_claims(attrs, TdCx.Auth.Claims)

  def dq_claims_factory(attrs), do: do_claims(attrs, TdDq.Auth.Claims)

  defp do_claims(attrs, module) do
    module
    |> Kernel.struct(
      user_id: sequence(:user_id, & &1),
      user_name: sequence("user_name"),
      role: "admin",
      jti: sequence("jti")
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
    attrs = default_assoc(attrs, :data_structure_id, :data_structure)

    %DataStructureVersion{
      description: "some description",
      group: "some group",
      name: "some name",
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
      business_concept_id: sequence(:business_concept_id, &"#{&1}"),
      domain_id: sequence(:domain_id, &"#{&1}"),
      description: %{"document" => "Rule Description"},
      goal: 30,
      minimum: 12,
      name: sequence("rule_name"),
      active: false,
      version: 1,
      updated_by: sequence(:updated_by, & &1),
      result_type: "percentage"
    }
  end

  def raw_implementation_factory do
    %TdDq.Implementations.Implementation{
      rule: build(:rule),
      implementation_key: sequence("ri"),
      implementation_type: "raw",
      raw_content: build(:raw_content),
      deleted_at: nil
    }
  end

  def raw_content_factory do
    %TdDq.Implementations.RawContent{
      dataset: "clientes c join address a on c.address_id=a.id",
      population: "a.country = 'SPAIN'",
      source_id: 1,
      database: "raw_database",
      validations: "a.city is null"
    }
  end

  def implementation_factory(attrs) do
    attrs = default_assoc(attrs, :rule_id, :rule)

    %TdDq.Implementations.Implementation{
      implementation_key: sequence("implementation_key"),
      implementation_type: "default",
      dataset: build(:dataset),
      population: build(:population),
      validations: build(:validations)
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

  def data_structure_tag_factory do
    %DataStructureTag{
      name: sequence("structure_tag_name")
    }
  end

  def data_structure_type_factory do
    %DataStructureType{
      structure_type: sequence("structure_type"),
      template_id: sequence(:template_id, & &1),
      translation: sequence("system_name"),
      metadata_fields: %{"foo" => "bar"}
    }
  end

  def system_factory do
    %System{
      name: sequence("system_name"),
      external_id: sequence("system_external_id")
    }
  end

  def relation_type_factory do
    %RelationType{
      name: "relation_type_name"
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

  def user_search_filter_factory do
    %UserSearchFilter{
      id: sequence(:user_search_filter, & &1),
      name: sequence("filter_name"),
      filters: %{country: ["Sp"]},
      user_id: sequence(:user_id, & &1)
    }
  end

  def domain_factory do
    %{
      name: sequence("domain_name"),
      id: sequence(:domain_id, &(&1 + 1000)),
      external_id: sequence("domain_external_id"),
      updated_at: DateTime.utc_now()
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
    %TdDd.Events.ProfileEvent{
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

  def job_factory do
    %Job{
      source: build(:source),
      type: sequence(:job_type, ["Metadata", "DQ", "Profile"])
    }
  end

  def event_factory do
    %Event{
      job: build(:job),
      type: sequence("event_type"),
      message: sequence("event_message")
    }
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

  def population_factory(_attrs) do
    [build(:condition_row)]
  end

  def validations_factory(_attrs) do
    [build(:condition_row)]
  end

  def condition_row_factory do
    %TdDq.Implementations.ConditionRow{
      value: [%{"raw" => 8}],
      operator: build(:operator),
      structure: build(:dataset_structure)
    }
  end

  def operator_factory do
    %TdDq.Implementations.Operator{name: "eq", value_type: "number"}
  end

  def rule_result_factory do
    %TdDq.Rules.RuleResult{
      implementation_key: sequence("ri"),
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

  def execution_factory do
    %TdDq.Executions.Execution{}
  end

  def execution_group_factory do
    %TdDq.Executions.Group{
      created_by_id: 0
    }
  end

  def quality_event_factory do
    %TdDq.Events.QualityEvent{
      type: "PENDING"
    }
  end

  def data_structures_tags_factory do
    %TdDd.DataStructures.DataStructuresTags{
      data_structure: build(:data_structure),
      data_structure_tag: build(:data_structure_tag),
      description: "foo"
    }
  end

  def classifier_factory(attrs) do
    attrs = default_assoc(attrs, :system_id, :system)

    %TdDd.Classifiers.Classifier{
      name: sequence("classification")
    }
    |> merge_attributes(attrs)
  end

  def grant_factory do
    %TdDd.Grants.Grant{
      data_structure: build(:data_structure),
      user_id: sequence(:user_id, &"#{&1}"),
      detail: %{"foo" => "bar"},
      start_date: DateTime.utc_now(),
      end_date: DateTime.utc_now()
    }
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

  defp default_assoc(attrs, id_key, key, build_key \\ nil) do
    if Enum.any?([key, id_key], &Map.has_key?(attrs, &1)) do
      attrs
    else
      build_key = if build_key, do: build_key, else: key
      Map.put(attrs, key, build(build_key))
    end
  end
end
