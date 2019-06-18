defmodule TdDq.Rules.Rule do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias TdDfLib.Format
  alias TdDq.Rules.Rule
  alias TdDq.Rules.RuleImplementation
  alias TdDq.Rules.RuleType
  alias TdDq.Searchable
  alias TdPerms.UserCache
  alias TdDq.Rules

  @df_cache Application.get_env(:td_dq, :df_cache)
  @taxonomy_cache Application.get_env(:td_dq, :taxonomy_cache)
  @bc_cache Application.get_env(:td_dq, :bc_cache)
  @behaviour Searchable

  schema "rules" do
    field(:business_concept_id, :string)
    field(:active, :boolean, default: false)
    field(:deleted_at, :utc_datetime)
    field(:description, :string)
    field(:goal, :integer)
    field(:minimum, :integer)
    field(:name, :string)
    field(:population, :string)
    field(:priority, :string)
    field(:weight, :integer)
    field(:version, :integer, default: 1)
    field(:updated_by, :integer)
    field(:type_params, :map)
    belongs_to(:rule_type, RuleType)

    has_many(:rule_implementations, RuleImplementation)

    field(:df_name, :string)
    field(:df_content, :map)

    timestamps()
  end

  @doc false
  def changeset(%Rule{} = rule, attrs) do
    rule
    |> cast(attrs, [
      :business_concept_id,
      :active,
      :name,
      :deleted_at,
      :description,
      :weight,
      :priority,
      :population,
      :goal,
      :minimum,
      :version,
      :updated_by,
      :rule_type_id,
      :type_params,
      :df_name,
      :df_content
    ])
    |> validate_required([
      :name,
      :goal,
      :minimum,
      :rule_type_id,
      :type_params
    ])
    |> unique_constraint(
      :rule_name_bc_id,
      name: :rules_business_concept_id_name_index,
      message: "unique_constraint"
    )
    |> unique_constraint(
      :rule_name_bc_id,
      name: :rules_name_index,
      message: "unique_constraint"
    )
    |> validate_number(:goal, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:minimum, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_goal
    |> foreign_key_constraint(:rule_type_id)
  end

  def delete_changeset(%Rule{} = rule) do
    rule
    |> change()
    |> no_assoc_constraint(:rule_implementations, message: "rule.delete.existing.implementations")
  end

  defp validate_goal(changeset) do
    case changeset.valid? do
      true ->
        minimum = get_field(changeset, :minimum)
        goal = get_field(changeset, :goal)

        case minimum <= goal do
          true -> changeset
          false -> add_error(changeset, :goal, "must.be.greater.than.or.equal.to.minimum")
        end

      _ ->
        changeset
    end
  end

  def search_fields(%Rule{} = rule) do
    template =
      case @df_cache.get_template_by_name(rule.df_name) do
        nil -> %{content: []}
        template -> template
      end

    updated_by =
      case UserCache.get_user(rule.updated_by) do
        nil -> %{}
        user -> user
      end

    df_content =
      rule
      |> Map.get(:df_content)
      |> Format.apply_template(Map.get(template, :content))

    rule_type = Map.take(rule.rule_type, [:id, :name, :params])

    current_business_concept_version =
      Map.get(rule, :current_business_concept_version, %{name: ""})

    domain_ids = retrieve_domain_ids(rule)
    domain_parents = Enum.map(domain_ids, &%{id: &1, name: @taxonomy_cache.get_name(&1)})

    execution_result_info =
      rule
      |> Rules.get_last_rule_implementations_result()
      |> get_execution_result_info(rule)

    %{
      id: rule.id,
      business_concept_id: rule.business_concept_id,
      domain_ids: domain_ids,
      domain_parents: domain_parents,
      current_business_concept_version: current_business_concept_version,
      rule_type_id: rule.rule_type_id,
      rule_type: rule_type,
      version: rule.version,
      name: rule.name,
      active: rule.active,
      description: rule.description,
      deleted_at: rule.deleted_at,
      execution_result_info: execution_result_info,
      updated_by: updated_by,
      updated_at: rule.updated_at,
      inserted_at: rule.inserted_at,
      goal: rule.goal,
      minimum: rule.minimum,
      weight: rule.weight,
      population: rule.population,
      priority: rule.priority,
      df_name: rule.df_name,
      df_content: df_content
    }
  end

  def get_execution_result_info([], rule) do
    %{}
  end
  def get_execution_result_info(rule_results, rule) do
    %{}
    |> with_avg(rule_results)
    |> with_last_execution_at(rule_results)
    |> with_result_text(rule.minimum, rule.goal)
  end

  defp with_avg(result_map, rule_results) do
    result_avg = rule_results
    |> Enum.map(& &1.result)
    |> Enum.sum

    result_avg = case length(rule_results) do
      0 -> 0
      results_length -> result_avg / results_length
    end
    Map.put(result_map, :result_avg, result_avg)
  end

  defp with_last_execution_at(result_map, rule_results) do
    last_execution_at = rule_results
    |> Enum.map( & &1.date)
    |> Enum.max()
    Map.put(result_map, :last_execution_at, last_execution_at)
  end

  defp with_result_text(result_map, minimum, goal) do
    result_text = cond do
      result_map.result_avg < minimum ->
        "result.under_minimum"
      result_map.result_avg >= minimum and result_map.result_avg < goal ->
        "result.under_goal"
        result_map.result_avg >= goal ->
          "result.over_goal"
    end
    Map.put(result_map, :result_text, result_text)
  end

  defp retrieve_domain_ids(%{business_concept_id: nil}), do: []
  defp retrieve_domain_ids(%{business_concept_id: business_concept_id}) do
    business_concept_id
      |> @bc_cache.get_parent_id
      |> String.to_integer
      |> @taxonomy_cache.get_parent_ids
  end

  def index_name do
    "quality_rule"
  end
end
