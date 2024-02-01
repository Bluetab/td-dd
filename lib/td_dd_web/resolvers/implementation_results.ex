defmodule TdDdWeb.Resolvers.ImplementationResults do
  @moduledoc """
  Absinthe resolvers for implementation results
  """

  import Canada, only: [can?: 2]

  alias TdDq.Rules.RuleResults

  def result(_parent, %{id: id}, resolution) do
    with {:claims, %{} = claims} <- {:claims, claims(resolution)},
         result <- RuleResults.get_rule_result(id),
         {:can, true} <- {:can, can?(claims, view(result))} do
      {:ok, result}
    else
      {:claims, nil} -> {:error, :unauthorized}
      {:can, false} -> {:error, :forbidden}
      {:error, :result, changeset, _} -> {:error, changeset}
    end
  end

  def has_segments?(rule_result, _args, _resolution) do
    {:ok, RuleResults.has_segments?(rule_result)}
  end

  def has_remediation?(rule_result, _args, _resolution) do
    {:ok, RuleResults.has_remediation?(rule_result)}
  end

  defp claims(%{context: %{claims: claims}}), do: claims
  defp claims(_), do: nil
end
