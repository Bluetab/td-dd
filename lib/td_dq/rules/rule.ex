defmodule TdDq.Rules.Rule do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias TdDq.Rules.Rule
  alias TdDq.Rules.RuleImplementation
  alias TdDq.Rules.RuleType

  @result_type %{
    percentage: "percentage",
    errors_number: "errors_number"
  }

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
    field(:type_params, :map)
    field(:result_type, :string, default: @result_type.percentage)
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
      :goal,
      :minimum,
      :version,
      :updated_by,
      :rule_type_id,
      :type_params,
      :df_name,
      :df_content,
      :result_type
    ])
    |> validate_required([
      :name,
      :goal,
      :minimum,
      :rule_type_id,
      :type_params,
      :result_type
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
        result_type = get_field(changeset, :result_type)
        do_validate_goal(changeset, minimum, goal, result_type)

      _ ->
        changeset
    end
  end

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

  def result_type do
    @result_type
  end

  defimpl Elasticsearch.Document do
    alias TdCache.ConceptCache
    alias TdCache.TaxonomyCache
    alias TdCache.TemplateCache
    alias TdCache.UserCache
    alias TdDfLib.Format
    alias TdDfLib.RichText
    alias TdDq.Rules

    @impl Elasticsearch.Document
    def id(%Rule{id: id}), do: id

    @impl Elasticsearch.Document
    def routing(_), do: false

    @impl Elasticsearch.Document
    def encode(%Rule{rule_type: rule_type} = rule) do
      template = TemplateCache.get_by_name!(rule.df_name) || %{content: []}
      updated_by = get_user(rule.updated_by)
      execution_result_info = get_execution_result_info(rule)
      confidential = confidential?(rule)
      rule_type = Map.take(rule_type, [:id, :name, :params])
      bcv = get_business_concept_version(rule)
      domain_ids = get_domain_ids(rule)
      domain_parents = get_domain_parents(domain_ids)

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
        rule_type_id: rule.rule_type_id,
        rule_type: rule_type,
        result_type: rule.result_type,
        type_params: rule.type_params,
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
      case Rules.get_latest_rule_results(rule) do
        [] -> %{result_text: "quality_result.no_execution"}
        results -> get_execution_result_info(rule, results)
      end
    end

    defp get_execution_result_info(
           %Rule{minimum: minimum, goal: goal, result_type: result_type} = rule,
           rule_results
         ) do
      Map.new()
      |> with_result(rule_results)
      |> with_last_execution_at(rule_results)
      |> with_result_text(minimum, goal, result_type)
    end

    defp with_result(result_map, rule_results) do
      result =
        rule_results
        |> Enum.min(fn rule_result -> rule_result.result end)

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

    defp with_result_text(%{result: result} = result_map, minimum, goal, "percentage") do
      result_text =
        cond do
          result < minimum ->
            "quality_result.under_minimum"

          result >= minimum and result < goal ->
            "quality_result.under_goal"

          result >= goal ->
            "quality_result.over_goal"
        end

      Map.put(result_map, :result_text, result_text)
    end

    defp with_result_text(%{errors: errors} = result_map, minimum, goal, "errors_number") do
      result_text =
        cond do
          errors > minimum ->
            "quality_result.under_minimum"

          errors <= minimum and errors > goal ->
            "quality_result.under_goal"

          errors <= goal ->
            "quality_result.over_goal"
        end

      Map.put(result_map, :result_text, result_text)
    end

    defp with_result_text(result_map, _minimum, _goal, _type) do
      result_map
    end

    defp get_domain_ids(%{business_concept_id: nil}), do: -1

    defp get_domain_ids(%{business_concept_id: business_concept_id}) do
      {:ok, domain_ids} = ConceptCache.get(business_concept_id, :domain_ids)
      domain_ids
    end

    defp confidential?(%{business_concept_id: nil}), do: false

    defp confidential?(%{business_concept_id: business_concept_id}) do
      {:ok, status} = ConceptCache.member_confidential_ids(business_concept_id)

      case status do
        1 -> true
        _ -> false
      end
    end

    defp get_user(user_id) do
      case UserCache.get(user_id) do
        {:ok, nil} -> %{}
        {:ok, user} -> user
      end
    end

    defp get_business_concept_version(%{business_concept_id: nil}), do: %{name: ""}

    defp get_business_concept_version(%{business_concept_id: business_concept_id}) do
      case ConceptCache.get(business_concept_id) do
        {:ok, %{} = concept} when map_size(concept) > 0 ->
          concept
          |> Map.take([:name, :id, :content])
          |> Map.put_new(:name, "")

        _ ->
          %{name: ""}
      end
    end

    defp get_domain_parents(domain_ids) do
      case domain_ids do
        -1 -> []
        _ -> Enum.map(domain_ids, &%{id: &1, name: TaxonomyCache.get_name(&1)})
      end
    end
  end
end
