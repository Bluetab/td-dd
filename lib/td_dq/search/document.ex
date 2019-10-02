alias Elasticsearch.Document
alias TdCache.ConceptCache
alias TdCache.UserCache
alias TdCache.TaxonomyCache
alias TdCache.TemplateCache
alias TdDfLib.Format
alias TdDq.Repo
alias TdDq.Rules
alias TdDq.Rules.Indexable
alias TdDq.Rules.Rule

defimpl Document, for: Rule do
  @impl Document
  def id(%Rule{id: id}), do: id

  @impl Document
  def routing(_), do: false

  @impl Document
  def encode(rule) do
    %{rule_type: rule_type} = Repo.preload(rule, :rule_type)

    %Indexable{rule: rule, rule_type: rule_type}
    |> Document.encode()
  end
end

defimpl Document, for: Indexable do
  @impl Document
  def id(%Indexable{rule: %{id: id}}), do: id

  @impl Document
  def routing(_), do: false

  @impl Document
  def encode(%Indexable{rule: rule, rule_type: rule_type}) do
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
      type_params: rule.type_params,
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

  defp get_execution_result_info(rule) do
    rule_results = Rules.get_last_rule_implementations_result(rule)

    case rule_results do
      [] -> %{result_text: "quality_result.no_execution"}
      _ -> get_execution_result_info(rule, rule_results)
    end
  end

  def get_execution_result_info(%{minimum: minimum, goal: goal}, rule_results) do
    Map.new()
    |> with_avg(rule_results)
    |> with_last_execution_at(rule_results)
    |> with_result_text(minimum, goal)
  end

  defp with_avg(result_map, rule_results) do
    result_avg =
      rule_results
      |> Enum.map(& &1.result)
      |> Enum.sum()

    result_avg =
      case length(rule_results) do
        0 -> 0
        results_length -> result_avg / results_length
      end

    Map.put(result_map, :result_avg, result_avg)
  end

  defp with_last_execution_at(result_map, rule_results) do
    last_execution_at =
      rule_results
      |> Enum.map(& &1.date)
      |> Enum.max()

    Map.put(result_map, :last_execution_at, last_execution_at)
  end

  defp with_result_text(result_map, minimum, goal) do
    result_text =
      cond do
        result_map.result_avg < minimum ->
          "quality_result.under_minimum"

        result_map.result_avg >= minimum and result_map.result_avg < goal ->
          "quality_result.under_goal"

        result_map.result_avg >= goal ->
          "quality_result.over_goal"
      end

    Map.put(result_map, :result_text, result_text)
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
      {:ok, nil} -> %{name: ""}
      {:ok, concept} -> Map.take(concept, [:name, :id])
      _ -> %{name: ""}
    end
  end

  defp get_domain_parents(domain_ids) do
    case domain_ids do
      -1 -> []
      _ -> Enum.map(domain_ids, &%{id: &1, name: TaxonomyCache.get_name(&1)})
    end
  end
end
