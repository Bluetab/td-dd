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

  defp claims(%{context: %{claims: claims}}), do: claims
  defp claims(_), do: nil

  def results_connection(
        %{implementation_ref: implementation_ref} = _implementation,
        args,
        _resolution
      ) do
    args =
      args
      |> Map.take([:first, :last, :after, :before, :filters])
      |> Map.new(&connection_param/1)
      |> Map.put(:implementation_ref, implementation_ref)
      |> put_order_by(args)

    {:ok, results_connection(args)}
  end

  defp connection_param({:after, cursor}), do: {:after, cursor}
  defp connection_param({:before, cursor}), do: {:before, cursor}
  defp connection_param({:first, first}), do: {:limit, first}
  defp connection_param({:last, last}), do: {:limit, last}

  defp put_order_by(args, %{after: _}), do: Map.put(args, :order_by, :id)
  defp put_order_by(args, %{last: _}), do: Map.put(args, :order_by, desc: :id)
  defp put_order_by(args, %{}), do: Map.put(args, :order_by, desc: :id)

  defp results_connection(args) do
    args
    |> RuleResults.min_max_count()
    |> read_page(fn ->
      RuleResults.list_rule_results_no_pagination(Map.put(args, :preload, :implementation))
    end)
  end

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

  defp read_page(%{count: count, min_id: min_id, max_id: max_id}, fun) do
    page = fun.()

    {start_cursor, end_cursor} =
      page
      |> Enum.map(& &1.id)
      |> Enum.min_max(fn -> {0, nil} end)

    %{
      page: Enum.sort_by(page, & &1.id, :desc),
      total_count: count,
      page_info: %{
        start_cursor: start_cursor,
        end_cursor: end_cursor,
        has_next_page: not is_nil(end_cursor) and end_cursor < max_id,
        has_previous_page: not is_nil(start_cursor) and start_cursor > min_id
      }
    }
  end
end
