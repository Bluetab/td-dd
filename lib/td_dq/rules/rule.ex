defmodule TdDq.Rules.Rule do
  @moduledoc """
  Ecto Schema module for quality rules.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdDfLib.Validation
  alias TdDq.Rules.Implementations.Implementation
  alias TdDq.Rules.Rule

  schema "rules" do
    field(:business_concept_id, :string)
    field(:active, :boolean, default: false)
    field(:deleted_at, :utc_datetime)
    field(:description, :map)
    field(:goal, :integer)
    field(:minimum, :integer)
    field(:name, :string)
    field(:version, :integer, default: 1)
    field(:updated_by, :integer)
    field(:result_type, :string, default: "percentage")

    has_many(:rule_implementations, Implementation)

    field(:df_name, :string)
    field(:df_content, :map)

    timestamps()
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = rule, params) do
    rule
    |> cast(params, [
      :business_concept_id,
      :active,
      :name,
      :deleted_at,
      :description,
      :goal,
      :minimum,
      :version,
      :updated_by,
      :df_name,
      :df_content,
      :result_type
    ])
    |> validate_required([
      :name,
      :goal,
      :minimum,
      :result_type
    ])
    |> validate_inclusion(:result_type, ["percentage", "errors_number"])
    |> validate_goal()
    |> validate_content()
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
  end

  def delete_changeset(%__MODULE__{} = rule) do
    rule
    |> change()
    |> no_assoc_constraint(:rule_implementations, message: "rule.delete.existing.implementations")
  end

  defp validate_goal(%{valid?: true} = changeset) do
    minimum = get_field(changeset, :minimum)
    goal = get_field(changeset, :goal)
    result_type = get_field(changeset, :result_type)
    do_validate_goal(changeset, minimum, goal, result_type)
  end

  defp validate_goal(changeset), do: changeset

  defp do_validate_goal(changeset, minimum, goal, "percentage") do
    changeset =
      changeset
      |> validate_number(:goal, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
      |> validate_number(:minimum, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)

    case minimum <= goal do
      true -> changeset
      false -> add_error(changeset, :goal, "must.be.greater.than.or.equal.to.minimum")
    end
  end

  defp do_validate_goal(changeset, minimum, goal, "errors_number") do
    changeset =
      changeset
      |> validate_number(:goal, greater_than_or_equal_to: 0)
      |> validate_number(:minimum, greater_than_or_equal_to: 0)

    case minimum >= goal do
      true -> changeset
      false -> add_error(changeset, :minimum, "must.be.greater.than.or.equal.to.goal")
    end
  end

  defp validate_content(%{} = changeset) do
    case get_field(changeset, :df_name) do
      nil ->
        validate_change(changeset, :df_content, empty_content_validator())

      template_name ->
        changeset
        |> validate_required(:df_content)
        |> validate_change(:df_content, Validation.validator(template_name))
    end
  end

  defp empty_content_validator do
    fn
      _, nil -> []
      _, value when value == %{} -> []
      field, _ -> [{field, :missing_type}]
    end
  end

  defimpl Elasticsearch.Document do
    alias Search.Helpers
    alias TdCache.TemplateCache
    alias TdDfLib.Format
    alias TdDfLib.RichText
    alias TdDq.Rules.Rule
    alias TdDq.Rules.RuleResults

    @impl Elasticsearch.Document
    def id(%Rule{id: id}), do: id

    @impl Elasticsearch.Document
    def routing(_), do: false

    @impl Elasticsearch.Document
    def encode(%Rule{} = rule) do
      template = TemplateCache.get_by_name!(rule.df_name) || %{content: []}
      updated_by = Helpers.get_user(rule.updated_by)
      execution_result_info = get_execution_result_info(rule)
      confidential = Helpers.confidential?(rule)
      bcv = Helpers.get_business_concept_version(rule)
      domain_ids = Helpers.get_domain_ids(rule)
      domain_parents = Helpers.get_domain_parents(domain_ids)

      df_content =
        rule
        |> Map.get(:df_content)
        |> Format.search_values(template)

      %{
        id: rule.id,
        business_concept_id: rule.business_concept_id,
        _confidential: confidential,
        domain_ids: domain_ids,
        domain_parents: domain_parents,
        current_business_concept_version: bcv,
        result_type: rule.result_type,
        version: rule.version,
        name: rule.name,
        active: rule.active,
        description: RichText.to_plain_text(rule.description),
        deleted_at: rule.deleted_at,
        execution_result_info: execution_result_info,
        updated_by: updated_by,
        updated_at: rule.updated_at,
        inserted_at: rule.inserted_at,
        goal: rule.goal,
        minimum: rule.minimum,
        df_name: rule.df_name,
        df_content: df_content
      }
    end

    defp get_execution_result_info(%Rule{} = rule) do
      case RuleResults.get_latest_rule_results(rule) do
        [] ->
          %{result_text: "quality_result.no_execution"}

        results ->
          get_execution_result_info(rule, results)
      end
    end

    defp get_execution_result_info(
           %Rule{minimum: minimum, goal: goal, result_type: result_type},
           rule_results
         ) do
      Map.new()
      |> with_result(rule_results)
      |> with_last_execution_at(rule_results)
      |> Helpers.with_result_text(minimum, goal, result_type)
    end

    defp with_result(result_map, rule_results) do
      result =
        rule_results
        |> Enum.min_by(fn rule_result -> rule_result.result end)

      result_map
      |> Map.put(:result, Map.get(result, :result))
      |> Map.put(:errors, Map.get(result, :errors))
      |> Map.put(:records, Map.get(result, :records))
    end

    defp with_last_execution_at(result_map, rule_results) do
      last_execution_at =
        rule_results
        |> Enum.map(& &1.date)
        |> Enum.max()

      Map.put(result_map, :last_execution_at, last_execution_at)
    end
  end
end
