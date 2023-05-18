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
      %{} = domain -> domain
      _ -> %{id: domain_id}
    end
  end

  def get_domain(_), do: %{}

  def get_domains([_ | _] = domain_ids) do
    Enum.map(domain_ids, fn domain_id ->
      get_domain(domain_id)
    end)
  end

  def get_domains(_), do: []

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

  def with_result_text(%{records: records} = result_map, _minimum, _goal, _result_type)
      when records === 0 do
    Map.put(result_map, :result_text, "quality_result.empty_dataset")
  end

  def with_result_text(%{result: result} = result_map, minimum, goal, result_type)
      when result_type in ["percentage", "deviation"] do
    result_text = status(Decimal.to_float(result), minimum, goal, result_type)
    Map.put(result_map, :result_text, result_text)
  end

  def with_result_text(%{errors: errors} = result_map, minimum, goal, "errors_number") do
    result_text = status(errors, minimum, goal, "errors_number")
    Map.put(result_map, :result_text, result_text)
  end

  def with_result_text(result_map, _minimum, _goal, _type) do
    result_map
  end

  defp status(result, minimum, goal, "percentage") do
    cond do
      # goal >= minimum. Intervals:
      #   [0, minimum) => error
      #   [minimum, goal) => warning
      #   [goal, max => OK
      result < minimum ->
        "quality_result.under_minimum"

      result >= minimum and result < goal ->
        "quality_result.under_goal"

      result >= goal ->
        "quality_result.over_goal"
    end
  end

  defp status(errors_absolute_or_perc, minimum, goal, result_type)
       when result_type in ["errors_number", "deviation"] do
    cond do
      # goal <= minimum. Intervals:
      #   [0, goal] => OK
      #   (goal, minimum] => warning
      #   (minimum, max => error
      errors_absolute_or_perc > minimum ->
        "quality_result.under_minimum"

      errors_absolute_or_perc <= minimum and errors_absolute_or_perc > goal ->
        "quality_result.under_goal"

      errors_absolute_or_perc <= goal ->
        "quality_result.over_goal"
    end
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
