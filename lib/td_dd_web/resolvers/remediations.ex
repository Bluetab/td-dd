defmodule TdDdWeb.Resolvers.Remediations do
  @moduledoc """
  Absinthe resolvers for remediations and related entities
  """

  alias TdDdWeb.Resolvers.Utils.CursorPagination
  alias TdDq.Remediations
  alias TdDq.Remediations.Remediation

  def remediation(_parent, %{id: id}, resolution) do
    with {:claims, %{} = claims} <- {:claims, claims(resolution)},
         {:remediation, %Remediation{} = remediation} <-
           {:remediation,
            Remediations.get_remediation(id, preload: [rule_result: :implementation])},
         :ok <-
           Bodyguard.permit(
             Remediations,
             :manage_remediations,
             claims,
             remediation
           ) do
      {:ok, remediation}
    else
      {:claims, nil} -> {:error, :unauthorized}
      {:remediation, nil} -> {:error, :not_found}
      {:error, :forbidden} -> {:error, :forbidden}
    end
  end

  def remediations_connection(_parent, args, resolution) do
    with {:claims, %{} = claims} <- {:claims, claims(resolution)},
         :ok <-
           Bodyguard.permit(Remediations, :manage_remediations, claims) do
      args_with_pagination =
        args
        |> Map.new(&connection_param/1)
        |> CursorPagination.put_order_by(args)

      {:ok, remediations_connection(args_with_pagination)}
    else
      {:claims, nil} -> {:error, :unauthorized}
      {:error, :forbidden} -> {:error, :forbidden}
    end
  end

  defp connection_param({:first, first}), do: {:limit, first}
  defp connection_param({:last, last}), do: {:limit, last}
  defp connection_param({key, _value} = tuple) when is_atom(key), do: tuple

  defp remediations_connection(args) do
    args
    |> Remediations.min_max_count()
    |> CursorPagination.read_page(fn -> Remediations.list_remediations(args) end)
  end

  defp claims(%{context: %{claims: claims}}), do: claims
  defp claims(_), do: nil
end
