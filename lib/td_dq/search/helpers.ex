defmodule TdDq.Search.Helpers do
  @moduledoc """
  Functions to fetch data to index
  """

  alias TdCache.ConceptCache
  alias TdCache.TaxonomyCache
  alias TdCache.UserCache
  alias TdDd.Cache.StructureEntry

  def get_domain(%{domain_id: domain_id}) when is_integer(domain_id) do
    get_domain(domain_id)
  end

  def get_domain(domain_id) when is_integer(domain_id) do
    case TaxonomyCache.get_domain(domain_id) do
      domain = %{} -> domain
      _ -> %{}
    end
  end

  def get_domain(_), do: %{}

  def get_domain_ids(%{id: id, parent_ids: parent_ids}), do: [id | parent_ids]

  def get_domain_ids(_), do: -1

  def get_domain_parents(%{parent_ids: parent_ids} = domain) do
    parents =
      parent_ids
      |> Enum.map(&get_domain/1)
      |> Enum.map(&Map.take(&1, [:id, :name]))

    [domain | parents]
  end

  def get_domain_parents(_), do: []

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

  def with_result_text(result_map, _minimum, _goal, "FAILED"),
    do: Map.put(result_map, :result_text, "quality_result.failed")

  def with_result_text(result_map, _minimum, _goal, _type) do
    result_map
  end

  @spec get_sources([non_neg_integer()]) :: [binary()]
  def get_sources(structure_ids) do
    structure_ids
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&StructureEntry.cache_entry/1)
    |> Enum.flat_map(fn
      %{metadata: %{"alias" => alias}} -> [alias]
      _ -> []
    end)
    |> Enum.uniq()
  end
end
