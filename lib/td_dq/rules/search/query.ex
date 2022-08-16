defmodule TdDq.Rules.Search.Query do
  @moduledoc """
  Support for building rule search queries.
  """

  alias Truedat.Search.Query

  @not_confidential %{term: %{"_confidential" => false}}
  @executable %{term: %{"executable" => true}}

  def build_filters(%{} = permissions) do
    permissions
    |> Map.take([
      "manage_confidential_business_concepts",
      "view_quality_rule",
      "manage_quality_rule_implementations",
      "manage_raw_quality_rule_implementations",
      "execute_quality_rule_implementations"
    ])
    |> Map.put_new("manage_confidential_business_concepts", :none)
    |> Map.put_new("view_quality_rule", :none)
    |> Map.put_new(
      [
        "manage_quality_rule_implementations",
        "manage_raw_quality_rule_implementations"
      ],
      [
        Map.get(permissions, "manage_quality_rule_implementations", :none),
        Map.get(permissions, "manage_raw_quality_rule_implementations", :none)
      ]
    )
    |> Map.drop([
      "manage_quality_rule_implementations",
      "manage_raw_quality_rule_implementations"
    ])
    |> Enum.reduce_while([], &reduce_term/2)
  end

  defp reduce_term({"view_quality_rule", :none}, _acc), do: {:halt, [%{match_none: %{}}]}
  defp reduce_term({"view_quality_rule", :all}, acc), do: {:cont, [%{match_all: %{}} | acc]}

  defp reduce_term({"view_quality_rule", domain_ids}, acc) do
    {:cont, [domain_filter(domain_ids) | acc]}
  end

  defp reduce_term({"manage_quality_rule_implementations", :none}, _acc) do
    {
      :cont,
      [
        %{
          must_not: [
            %{term: %{"status" => "draft"}}
          ]
        }
      ]
    }
  end

  defp reduce_term(
         {[
            "manage_quality_rule_implementations",
            "manage_raw_quality_rule_implementations"
          ], perm},
         acc
       ) do
    case perm do
      [:none, _] ->
        reduce_term({"manage_quality_rule_implementations", :none}, acc)

      [_, :none] ->
        reduce_term({"manage_quality_rule_implementations", :none}, acc)

      [:all, :all] ->
        {:cont, [%{match_all: %{}} | acc]}

      [qr_domain_ids, rqr_domains_ids] ->
        domain_ids = qr_domain_ids -- qr_domain_ids -- rqr_domains_ids
        {:cont, [domain_filter(domain_ids) | acc]}
    end
  end

  defp reduce_term({"manage_confidential_business_concepts", :none}, acc),
    do: {:cont, [@not_confidential | acc]}

  defp reduce_term({"manage_confidential_business_concepts", :all}, acc), do: {:cont, acc}

  defp reduce_term({"manage_confidential_business_concepts", domain_ids}, acc) do
    filter = %{
      bool: %{
        should: [
          domain_filter(domain_ids),
          @not_confidential
        ]
      }
    }

    {:cont, [filter | acc]}
  end

  defp reduce_term({"execute_quality_rule_implementations", :none}, _acc),
    do: {:halt, [%{match_none: %{}}]}

  defp reduce_term({"execute_quality_rule_implementations", :all}, acc),
    do: {:cont, [@executable | acc]}

  defp reduce_term({"execute_quality_rule_implementations", domain_ids}, acc) do
    {:cont, [@executable, domain_filter(domain_ids) | acc]}
  end

  def build_query(%{} = permissions, params, aggs) do
    permissions
    |> build_filters()
    |> Query.build_query(params, aggs)
  end

  defp domain_filter(domain_ids) do
    Query.term_or_terms("domain_ids", domain_ids)
  end
end
