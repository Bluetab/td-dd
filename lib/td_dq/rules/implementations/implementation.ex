defmodule TdDq.Rules.Implementations.Implementation do
  @moduledoc """
  Ecto Schema module for Quality Rule Implementations
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias Ecto.Changeset
  alias TdDq.Rules.Implementations
  alias TdDq.Rules.Implementations.ConditionRow
  alias TdDq.Rules.Implementations.DatasetRow
  alias TdDq.Rules.Implementations.Implementation
  alias TdDq.Rules.Implementations.RawContent
  alias TdDq.Rules.Rule

  schema "rule_implementations" do
    field(:implementation_key, :string)
    field(:implementation_type, :string, default: "default")

    embeds_many(:dataset, DatasetRow, on_replace: :delete)
    embeds_many(:population, ConditionRow, on_replace: :delete)
    embeds_many(:validations, ConditionRow, on_replace: :delete)

    embeds_one(:raw_content, RawContent, on_replace: :delete)

    belongs_to(:rule, Rule)

    field(:deleted_at, :utc_datetime)
    timestamps()
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = implementation, params) do
    implementation
    |> cast(params, [
      :deleted_at,
      :rule_id,
      :implementation_key,
      :implementation_type
    ])
    |> validate_required([:implementation_type, :rule_id])
    |> validate_inclusion(:implementation_type, ["default", "raw"])
    |> validate_or_put_implementation_key()
    |> foreign_key_constraint(:rule_id)
    |> custom_changeset(implementation)
  end

  defp validate_or_put_implementation_key(%Changeset{valid?: true} = changeset) do
    case get_field(changeset, :implementation_key) do
      nil ->
        put_change(changeset, :implementation_key, Implementations.next_key())

      _ ->
        changeset
        |> validate_required([:implementation_key])
        |> validate_length(:implementation_key, max: 255)
        |> validate_format(:implementation_key, ~r/^[A-z0-9]*$/)
        |> unique_constraint(:implementation_key,
          name: :rule_implementations_implementation_key_index,
          message: "duplicated"
        )
    end
  end

  defp validate_or_put_implementation_key(%Changeset{} = changeset), do: changeset

  defp custom_changeset(
         %Changeset{changes: %{implementation_type: "raw"}} = changeset,
         _implementation
       ) do
    raw_changeset(changeset)
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
    |> validate_required([:raw_content])
  end

  def default_changeset(changeset) do
    changeset
    |> cast_embed(:dataset, with: &DatasetRow.changeset/2, required: true)
    |> cast_embed(:population, with: &ConditionRow.changeset/2, required: false)
    |> cast_embed(:validations, with: &ConditionRow.changeset/2, required: true)
    |> validate_required([:dataset, :validations])
  end

  defimpl Elasticsearch.Document do
    alias Search.Helpers
    alias TdCache.TemplateCache
    alias TdDfLib.Format
    alias TdDq.Rules.Rule
    alias TdDq.Rules.RuleResults

    @implementation_keys [
      :dataset,
      :deleted_at,
      :id,
      :implementation_key,
      :implementation_type,
      :population,
      :rule_id,
      :inserted_at,
      :updated_at,
      :validations
    ]
    @rule_keys [
      :active,
      :goal,
      :id,
      :minimum,
      :name,
      :version,
      :df_name,
      :df_content,
      :result_type
    ]

    @impl Elasticsearch.Document
    def id(%Implementation{id: id}), do: id

    @impl Elasticsearch.Document
    def routing(_), do: false

    @impl Elasticsearch.Document
    def encode(
          %Implementation{implementation_key: implementation_key, rule: rule} = implementation
        ) do
      confidential = Helpers.confidential?(rule)
      bcv = Helpers.get_business_concept_version(rule)
      execution_result_info = get_execution_result_info(rule, implementation_key)
      domain_ids = Helpers.get_domain_ids(rule)
      domain_parents = Helpers.get_domain_parents(domain_ids)
      updated_by = Helpers.get_user(rule.updated_by)
      structure_ids = Implementations.get_structure_ids(implementation)
      structure_aliases = Helpers.get_sources(structure_ids)

      implementation
      |> Implementations.enrich_implementation_structures()
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
      |> Map.put(:domain_parents, domain_parents)
      |> Map.put(:current_business_concept_version, bcv)
      |> Map.put(:_confidential, confidential)
      |> Map.put(:business_concept_id, Map.get(rule, :business_concept_id))
    end

    defp get_execution_result_info(%Rule{} = rule, implementation_key) do
      case RuleResults.get_latest_rule_result(implementation_key) do
        nil -> %{result_text: "quality_result.no_execution"}
        result -> build_result_info(rule, result)
      end
    end

    defp build_result_info(
           %Rule{minimum: minimum, goal: goal, result_type: result_type},
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

    defp get_raw_content(implementation) do
      raw_content = Map.get(implementation, :raw_content) || %{}

      raw_content
      |> Map.take([:dataset, :population, :validations, :structure_alias, :source_id, :database])
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
    end

    defp condition_row(row) do
      Map.new()
      |> Map.put(:operator, get_operator_fields(Map.get(row, :operator, %{})))
      |> Map.put(:structure, get_structure_fields(Map.get(row, :structure, %{})))
      |> Map.put(:value, Map.get(row, :value, []))
    end

    defp get_clause(row) do
      left = Map.get(row, :left, %{})
      right = Map.get(row, :right, %{})

      Map.new()
      |> Map.put(:left, get_structure_fields(left))
      |> Map.put(:right, get_structure_fields(right))
    end

    defp get_structure_fields(structure) do
      Map.take(structure, [:external_id, :id, :name, :path, :system, :type, :metadata])
    end

    defp get_operator_fields(operator) do
      Map.take(operator, [:name, :value_type, :value_type_filter])
    end

    defp with_rule(data, rule) do
      template = TemplateCache.get_by_name!(rule.df_name) || %{content: []}

      df_content =
        rule
        |> Map.get(:df_content)
        |> Format.search_values(template)

      rule = Map.put(rule, :df_content, df_content)
      Map.put(data, :rule, Map.take(rule, @rule_keys))
    end
  end
end
