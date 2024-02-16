defmodule TdDdWeb.Resolvers.ImplementationResults do
  @moduledoc """
  Absinthe resolvers for implementation results
  """

  alias TdDq.Rules.RuleResults

  def result(_parent, %{id: id}, resolution) do
    with {:claims, %{} = claims} <- {:claims, claims(resolution)},
         result <- RuleResults.get_rule_result(id, preload: [:implementation]),
         :ok <- Bodyguard.permit(RuleResults, :view, claims, result) do
      {:ok, result}
    else
      {:claims, nil} -> {:error, :unauthorized}
      {:error, :forbidden} -> {:error, :forbidden}
      {:error, :result, changeset, _} -> {:error, changeset}
    end
  end

  def has_segments?(rule_result, _args, _resolution) do
    {:ok, RuleResults.has_segments?(rule_result)}
  end

  def has_remediation?(rule_result, _args, _resolution) do
    {:ok, RuleResults.has_remediation?(rule_result)}
  end

  def results_connection(
        %{implementation_ref: implementation_ref} = _implementation,
        args,
        _resolution
      ) do
    args
    |> Map.take([:first, :last, :after, :before, :filters])
    |> Map.new(&connection_param/1)
    |> Map.put(:implementation_ref, implementation_ref)
    |> Map.put(:order_by, [:desc, :imp_version, :result_date, :result_id])
    |> read_page()
    |> then(&{:ok, &1})
  end

  defp claims(%{context: %{claims: claims}}), do: claims
  defp claims(_), do: nil

  defp connection_param({:after, cursor}), do: {:after, cursor}
  defp connection_param({:before, cursor}), do: {:before, cursor}
  defp connection_param({:first, first}), do: {:limit, first}
  defp connection_param({:last, last}), do: {:limit, last}

  defp read_page(conn_params) do
    page =
      conn_params
      |> Map.put(:preload, :implementation)
      |> RuleResults.list_rule_results()

    [start_cursor, end_cursor] =
      [List.last(page, %{}), List.first(page, %{})] |> Enum.map(&Map.get(&1, :id))

    %{count: count, last_cursor: last_cursor, first_cursor: first_cursor} =
      RuleResults.min_max_count(conn_params)

    %{
      page: page,
      total_count: count,
      page_info: %{
        start_cursor: start_cursor,
        end_cursor: end_cursor,
        has_next_page: not is_nil(start_cursor) and end_cursor != first_cursor.id,
        has_previous_page: not is_nil(end_cursor) and start_cursor != last_cursor.id
      }
    }
  end
end
