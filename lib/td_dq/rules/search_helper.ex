defmodule Search.Helpers do
  @moduledoc """
  Functions to fetch data to index
  """

  alias TdCache.ConceptCache
  alias TdCache.TaxonomyCache
  alias TdCache.UserCache

  def get_domain_ids(%{business_concept_id: nil}), do: -1

  def get_domain_ids(%{business_concept_id: business_concept_id}) do
    {:ok, domain_ids} = ConceptCache.get(business_concept_id, :domain_ids, refresh: true)
    domain_ids
  end

  def confidential?(%{business_concept_id: nil}), do: false

  def confidential?(%{business_concept_id: business_concept_id}) do
    {:ok, status} = ConceptCache.member_confidential_ids(business_concept_id)

    case status do
      1 -> true
      _ -> false
    end
  end

  def get_user(user_id) do
    case UserCache.get(user_id) do
      {:ok, nil} -> %{}
      {:ok, user} -> user
    end
  end

  def get_business_concept_version(%{business_concept_id: nil}), do: %{name: ""}

  def get_business_concept_version(%{business_concept_id: business_concept_id}) do
    case ConceptCache.get(business_concept_id, refresh: true) do
      {:ok, %{} = concept} when map_size(concept) > 0 ->
        concept
        |> Map.take([:name, :id, :content])
        |> Map.put_new(:name, "")

      _ ->
        %{name: ""}
    end
  end

  def get_domain_parents(domain_ids) do
    case domain_ids do
      -1 -> []
      _ -> Enum.map(domain_ids, &%{id: &1, name: TaxonomyCache.get_name(&1)})
    end
  end

  def with_result_text(%{result: result} = result_map, minimum, goal, "percentage") do
    result = Decimal.to_float(result)

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

  def with_result_text(%{errors: errors} = result_map, minimum, goal, "errors_number") do
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

  def with_result_text(result_map, _minimum, _goal, _type) do
    result_map
  end
end
