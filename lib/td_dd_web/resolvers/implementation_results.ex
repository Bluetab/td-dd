defmodule TdDdWeb.Resolvers.ImplementationResults do
  @moduledoc """
  Absinthe resolvers for implementation results
  """

  alias TdDq.Rules.RuleResults

  def result(_parent, %{id: id}, resolution) do
    with {:claims, %{} = claims} <- {:claims, claims(resolution)},
         result <- RuleResults.get_rule_result(id),
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

  def results_connection(conn_params) do
    conn_params
    |> RuleResults.min_max_count()
    |> read_page(fn ->
      RuleResults.list_rule_results(Map.put(conn_params, :preload, :implementation))
    end)
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
    |> put_order_by()
    |> results_connection()
    |> then(&{:ok, &1})
  end

  defp claims(%{context: %{claims: claims}}), do: claims
  defp claims(_), do: nil

  defp connection_param({:after, cursor}), do: {:after, cursor}
  defp connection_param({:before, cursor}), do: {:before, cursor}
  defp connection_param({:first, first}), do: {:limit, first}
  defp connection_param({:last, last}), do: {:limit, last}

  defp put_order_by(conn_params),
    do: Map.put(conn_params, :order_by, [:desc, :imp_version, :result_date, :result_id])

  defp read_page(%{count: 0}, _fun) do
    %{
      total_count: 0,
      page: [],
      page_info: %{
        start_cursor: nil,
        end_cursor: nil,
        has_next_page: false,
        has_previous_page: false
      }
    }
  end

  defp read_page(%{count: count, last_cursor: last_cursor, first_cursor: first_cursor}, fun) do
    page = fun.()

    [{start_cursor}, {end_cursor}] = [List.last(page), List.first(page)] |> Enum.map(&{&1.id})

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
