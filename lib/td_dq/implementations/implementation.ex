defmodule TdDq.Implementations.Implementation do
  @moduledoc """
  Ecto Schema module for Quality Rule Implementations
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias Ecto.Changeset
  alias TdDfLib.Validation
  alias TdDq.Events.QualityEvents
  alias TdDq.Implementations
  alias TdDq.Implementations.ConditionRow
  alias TdDq.Implementations.DatasetRow
  alias TdDq.Implementations.Implementation
  alias TdDq.Implementations.RawContent
  alias TdDq.Rules.Rule
  alias TdDq.Rules.RuleResult
  alias TdDq.Rules.RuleResults
  alias TdDq.Search.Helpers

  @valid_result_types ~w(percentage errors_number deviation)
  @typedoc "A quality rule implementation"
  @type t :: %__MODULE__{}

  schema "rule_implementations" do
    field(:implementation_key, :string)
    field(:implementation_type, :string, default: "default")
    field(:executable, :boolean, default: true)
    field(:deleted_at, :utc_datetime)
    field(:domain_id, :integer)
    field(:df_name, :string)
    field(:df_content, :map)
    field(:goal, :float)
    field(:minimum, :float)
    field(:result_type, :string, default: "percentage")

    embeds_one(:raw_content, RawContent, on_replace: :delete)
    embeds_many(:dataset, DatasetRow, on_replace: :delete)
    embeds_many(:population, ConditionRow, on_replace: :delete)
    embeds_many(:validations, ConditionRow, on_replace: :delete)

    belongs_to(:rule, Rule)

    has_many(:results, RuleResult)

    timestamps(type: :utc_datetime)
  end

  def valid_result_types, do: @valid_result_types

  def changeset(%__MODULE__{} = implementation, params) do
    implementation
    |> cast(params, [
      :deleted_at,
      :df_content,
      :df_name,
      :executable,
      :goal,
      :implementation_key,
      :implementation_type,
      :minimum,
      :result_type,
      :rule_id
    ])
    |> validate_required([
      :domain_id,
      :executable,
      :goal,
      :implementation_type,
      :minimum,
      :result_type,
      :rule_id
    ])
    |> validate_inclusion(:implementation_type, ["default", "raw", "draft"])
    |> validate_inclusion(:result_type, @valid_result_types)
    |> validate_or_put_implementation_key()
    |> maybe_put_identifier(implementation, params)
    |> validate_content()
    |> validate_goal()
    |> foreign_key_constraint(:rule_id)
    |> custom_changeset(implementation)
  end

  defp maybe_put_identifier(
         changeset,
         %__MODULE__{df_content: old_content} = _implementation,
         %{"df_name" => template_name} = _params
       ) do
    maybe_put_identifier_aux(changeset, old_content, template_name)
  end

  defp maybe_put_identifier(
         changeset,
         %__MODULE__{} = _implementation,
         %{"df_name" => template_name} = _params
       ) do
    maybe_put_identifier_aux(changeset, %{}, template_name)
  end

  defp maybe_put_identifier(changeset, _implementation, _params) do
    changeset
  end

  defp maybe_put_identifier_aux(
         %{valid?: true, changes: %{df_content: changeset_content}} = changeset,
         old_content,
         template_name
       ) do
    TdDfLib.Format.maybe_put_identifier(changeset_content, old_content, template_name)
    |> (fn new_content ->
          put_change(changeset, :df_content, new_content)
        end).()
  end

  defp maybe_put_identifier_aux(changeset, _, _) do
    changeset
  end

  defp validate_or_put_implementation_key(%Changeset{valid?: true} = changeset) do
    case get_field(changeset, :implementation_key) do
      nil ->
        put_change(changeset, :implementation_key, Implementations.next_key())

      _ ->
        changeset
        |> validate_required([:implementation_key])
        |> validate_length(:implementation_key, max: 255)
        |> unique_constraint(:implementation_key,
          name: :rule_implementations_implementation_key_index,
          message: "duplicated"
        )
    end
  end

  defp validate_or_put_implementation_key(%Changeset{} = changeset), do: changeset

  defp validate_content(%{} = changeset) do
    if template_name = get_field(changeset, :df_name) do
      changeset
      |> validate_required(:df_content)
      |> validate_change(:df_content, Validation.validator(template_name))
    else
      validate_change(changeset, :df_content, &empty_content_validator/2)
    end
  end

  defp empty_content_validator(_, value) when is_nil(value) or value == %{}, do: []
  defp empty_content_validator(field, _), do: [{field, "missing_type"}]

  defp validate_goal(%{valid?: true} = changeset) do
    minimum = get_field(changeset, :minimum)
    goal = get_field(changeset, :goal)
    result_type = get_field(changeset, :result_type)
    do_validate_goal(changeset, minimum, goal, result_type)
  end

  defp validate_goal(changeset), do: changeset

  defp do_validate_goal(changeset, minimum, goal, result_type)
       when result_type in ["percentage", "deviation"] do
    changeset
    |> validate_number(:goal, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:minimum, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> minimum_goal_check(minimum, goal, result_type)
  end

  defp do_validate_goal(changeset, minimum, goal, "errors_number") do
    changeset
    |> validate_number(:goal, greater_than_or_equal_to: 0)
    |> validate_number(:minimum, greater_than_or_equal_to: 0)
    |> minimum_goal_check(minimum, goal, "errors_number")
  end

  def minimum_goal_check(changeset, minimum, goal, "percentage") do
    case minimum <= goal do
      true -> changeset
      false -> add_error(changeset, :goal, "must.be.greater.than.or.equal.to.minimum")
    end
  end

  def minimum_goal_check(changeset, minimum, goal, result_type)
      when result_type in ["errors_number", "deviation"] do
    case minimum >= goal do
      true -> changeset
      false -> add_error(changeset, :minimum, "must.be.greater.than.or.equal.to.goal")
    end
  end

  defp custom_changeset(
         %Changeset{changes: %{implementation_type: "raw"}} = changeset,
         _implementation
       ) do
    raw_changeset(changeset)
  end

  defp custom_changeset(
         %Changeset{changes: %{implementation_type: "draft"}} = changeset,
         _implementation
       ) do
    draft_changeset(changeset)
  end

  defp custom_changeset(%Changeset{} = changeset, %__MODULE__{implementation_type: "raw"}) do
    raw_changeset(changeset)
  end

  defp custom_changeset(
         %Changeset{changes: %{implementation_type: _type}} = changeset,
         _implementation
       ) do
    default_changeset(changeset)
  end

  defp custom_changeset(%Changeset{} = changeset, %__MODULE__{implementation_type: _type}) do
    default_changeset(changeset)
  end

  defp raw_changeset(changeset) do
    changeset
    |> cast_embed(:raw_content, with: &RawContent.changeset/2, required: true)
    |> validate_required(:raw_content)
  end

  defp draft_changeset(changeset), do: changeset

  def default_changeset(changeset) do
    changeset
    |> cast_embed(:dataset, with: &DatasetRow.changeset/2, required: true)
    |> cast_embed(:population, with: &ConditionRow.changeset/2, required: false)
    |> cast_embed(:validations, with: &ConditionRow.changeset/2, required: true)
    |> validate_required([:dataset, :validations])
  end

  def get_execution_result_info(_implementation, %{type: "FAILED", inserted_at: inserted_at}) do
    %{result_text: "quality_result.failed", date: inserted_at}
  end

  def get_execution_result_info(%Implementation{} = implementation, _quality_event) do
    case RuleResults.get_latest_rule_result(implementation) do
      nil -> %{result_text: nil}
      result -> build_result_info(implementation, result)
    end
  end

  defp build_result_info(
         %Implementation{minimum: minimum, goal: goal, result_type: result_type},
         rule_result
       ) do
    Map.new()
    |> with_result(rule_result)
    |> with_date(rule_result)
    |> Helpers.with_result_text(minimum, goal, result_type)
  end

  defp with_result(result_map, rule_result) do
    rule_result
    |> Map.take([:result, :errors, :records])
    |> Map.merge(result_map)
  end

  defp with_date(result_map, rule_result) do
    Map.put(result_map, :date, Map.get(rule_result, :date))
  end

  defimpl Elasticsearch.Document do
    alias TdCache.TemplateCache
    alias TdDfLib.Format
    alias TdDq.Search.Helpers

    @implementation_keys [
      :dataset,
      :deleted_at,
      :domain_id,
      :id,
      :implementation_key,
      :implementation_type,
      :population,
      :rule_id,
      :inserted_at,
      :updated_at,
      :validations,
      :df_name,
      :executable,
      :goal,
      :minimum,
      :result_type
    ]
    @rule_keys [
      :active,
      :id,
      :name,
      :version,
      :df_name,
      :df_content
    ]

    @impl Elasticsearch.Document
    def id(%Implementation{id: id}), do: id

    @impl Elasticsearch.Document
    def routing(_), do: false

    @impl Elasticsearch.Document
    def encode(%Implementation{rule: rule, id: implementation_id} = implementation) do
      implementation = Implementations.enrich_implementation_structures(implementation)
      quality_event = QualityEvents.get_event_by_imp(implementation_id)
      confidential = Helpers.confidential?(rule)
      bcv = Helpers.get_business_concept_version(rule)
      execution_result_info = Implementation.get_execution_result_info(implementation, quality_event)
      domain = Helpers.get_domain(implementation)
      domain_ids = Helpers.get_domain_ids(domain)
      domain_parents = Helpers.get_domain_parents(domain)
      updated_by = Helpers.get_user(rule.updated_by)
      structures = Implementations.get_structures(implementation)
      structure_ids = get_structure_ids(structures)
      structure_names = get_structure_names(structures)
      structure_aliases = Implementations.get_sources(implementation)

      template = TemplateCache.get_by_name!(implementation.df_name) || %{content: []}

      df_content =
        implementation
        |> Map.get(:df_content)
        |> Format.search_values(template)

      implementation
      |> Map.take(@implementation_keys)
      |> transform_dataset()
      |> transform_population()
      |> transform_validations()
      |> with_rule(rule)
      |> Map.put(:raw_content, get_raw_content(implementation))
      |> Map.put(:rule, Map.take(rule, @rule_keys))
      |> Map.put(:structure_aliases, structure_aliases)
      |> Map.put(:updated_by, updated_by)
      |> Map.put(:execution_result_info, execution_result_info)
      |> Map.put(:domain_ids, domain_ids)
      |> Map.put(:structure_ids, structure_ids)
      |> Map.put(:structure_names, structure_names)
      |> Map.put(:domain_parents, domain_parents)
      |> Map.put(:current_business_concept_version, bcv)
      |> Map.put(:_confidential, confidential)
      |> Map.put(:business_concept_id, Map.get(rule, :business_concept_id))
      |> Map.put(:df_content, df_content)
    end

    defp get_raw_content(implementation) do
      raw_content = Map.get(implementation, :raw_content) || %{}

      Map.take(raw_content, [
        :dataset,
        :population,
        :validations,
        :source_id,
        :database
      ])
    end

    defp transform_dataset(%{dataset: dataset = [_ | _]} = data) do
      Map.put(data, :dataset, Enum.map(dataset, &dataset_row/1))
    end

    defp transform_dataset(data), do: data

    defp transform_population(%{population: population = [_ | _]} = data) do
      Map.put(data, :population, Enum.map(population, &condition_row/1))
    end

    defp transform_population(data), do: data

    defp transform_validations(%{validations: validations = [_ | _]} = data) do
      Map.put(data, :validations, Enum.map(validations, &condition_row/1))
    end

    defp transform_validations(data), do: data

    defp dataset_row(row) do
      Map.new()
      |> Map.put(:clauses, Enum.map(Map.get(row, :clauses, []), &get_clause/1))
      |> Map.put(:structure, get_structure_fields(Map.get(row, :structure, %{})))
      |> Map.put(:join_type, Map.get(row, :join_type))
      |> Map.put(:alias, get_alias_fields(Map.get(row, :alias)))
    end

    defp condition_row(row) do
      Map.new()
      |> Map.put(:operator, get_operator_fields(Map.get(row, :operator, %{})))
      |> Map.put(:structure, get_structure_fields(Map.get(row, :structure, %{})))
      |> Map.put(:value, Map.get(row, :value, []))
      |> Map.put(:modifier, Map.get(row, :modifier, []))
      |> Map.put(:value_modifier, Map.get(row, :value_modifier, []))
      |> with_population(row)
    end

    defp get_clause(row) do
      left = Map.get(row, :left, %{})
      right = Map.get(row, :right, %{})

      Map.new()
      |> Map.put(:left, get_structure_fields(left))
      |> Map.put(:right, get_structure_fields(right))
    end

    defp get_structure_fields(structure) do
      Map.take(structure, [
        :external_id,
        :id,
        :name,
        :path,
        :system,
        :type,
        :metadata,
        :parent_index
      ])
    end

    defp get_alias_fields(nil), do: nil
    defp get_alias_fields(alias_value), do: Map.take(alias_value, [:index, :text])

    defp get_operator_fields(operator) do
      Map.take(operator, [:name, :value_type, :value_type_filter])
    end

    defp with_population(data, %{population: population = [_ | _]}) do
      Map.put(data, :population, Enum.map(population, &condition_row/1))
    end

    defp with_population(data, _condition), do: data

    defp with_rule(data, rule) do
      template = TemplateCache.get_by_name!(rule.df_name) || %{content: []}

      df_content =
        rule
        |> Map.get(:df_content)
        |> Format.search_values(template)

      rule = Map.put(rule, :df_content, df_content)
      Map.put(data, :rule, Map.take(rule, @rule_keys))
    end

    defp get_structure_ids(structures) do
      structures
      |> Enum.map(&Map.get(&1, :id))
      |> Enum.uniq()
    end

    defp get_structure_names(structures) do
      structures
      |> Enum.map(&Map.get(&1, :name))
      |> Enum.filter(& &1)
      |> Enum.uniq()
    end
  end
end
