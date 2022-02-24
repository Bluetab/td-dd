defmodule TdDq.Rules.Search.Query do
  @moduledoc """
  Support for building search queries.
  """

  @not_confidential %{term: %{"_confidential" => false}}

  import Truedat.Search.Query, only: [term_or_terms: 2]

  def build_filters(%{} = permissions) do
    permissions
    |> Map.take([
      "manage_confidential_business_concepts",
      "view_quality_rule",
      "execute_quality_rule_implementations"
    ])
    |> Map.put_new("manage_confidential_business_concepts", :none)
    |> Map.put_new("view_quality_rule", :none)
    |> Enum.reduce_while([], &reduce_term/2)
  end

  defp reduce_term({"view_quality_rule", :none}, _acc), do: {:halt, [%{match_none: %{}}]}
  defp reduce_term({"view_quality_rule", :all}, acc), do: {:cont, [%{match_all: %{}} | acc]}

  defp reduce_term({"view_quality_rule", domain_ids}, acc) do
    {:cont, [term_or_terms("domain_id", domain_ids) | acc]}
  end

  defp reduce_term({"manage_confidential_business_concepts", :none}, acc),
    do: {:cont, [@not_confidential | acc]}

  defp reduce_term({"manage_confidential_business_concepts", :all}, acc), do: {:cont, acc}

  defp reduce_term({"manage_confidential_business_concepts", domain_ids}, acc) do
    filter = %{
      bool: %{
        should: [
          term_or_terms("domain_id", domain_ids),
          @not_confidential
        ]
      }
    }

    {:cont, [filter | acc]}
  end

  defp reduce_term({"execute_quality_rule_implementations", :none}, _acc),
    do: {:halt, [%{match_none: %{}}]}

  defp reduce_term({"execute_quality_rule_implementations", :all}, acc), do: {:cont, acc}

  defp reduce_term({"execute_quality_rule_implementations", domain_ids}, acc) do
    {:cont, [term_or_terms("domain_id", domain_ids) | acc]}
  end

  def build_query(filters, params, aggs) do
    Truedat.Search.Query.build_query(filters, params, aggs)
  end
end
