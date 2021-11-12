defmodule TdDd.Grants.BulkLoad do
  @moduledoc """
  Bulk load grants.
  """

  import Canada, only: [can?: 2]

  alias Ecto.Multi
  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDd.Grants
  alias TdDd.Repo
  alias TdDd.Search.IndexWorker

  require Logger

  def bulk_load(claims, grants) do
    Logger.info("Loading Grant Requests")

    Timer.time(
      fn -> do_bulk_load(claims, grants) end,
      fn millis, _ -> Logger.info("Grant Requests loaded in #{millis}ms") end
    )
  end

  defp do_bulk_load(claims, grants) do
    Multi.new()
    |> Multi.run(:ids, fn _, _ -> bulk_insert_grants(claims, grants) end)
    |> Repo.transaction()
    |> case do
      {:ok, %{ids: ids}} ->
        {:ok, ids}

      {:error, _, error, _} ->
        {:error, error}
    end
    |> do_reindex()
  end

  defp bulk_insert_grants(claims, grants) do
    grants
    |> reduce_insert_grant(claims)
    |> case do
      ids when is_list(ids) -> {:ok, ids}
      error -> error
    end
  end

  defp reduce_insert_grant(grants, claims), do: reduce_insert_grant(grants, claims, [])

  defp reduce_insert_grant([], _claims, acc), do: acc

  defp reduce_insert_grant(
         [
           %{"op" => "add", "data_structure_external_id" => data_structure_external_id} =
             grant_params
           | tail
         ],
         claims,
         acc
       ) do
    with {:data_structure, %DataStructure{} = data_structure} <-
           {:data_structure,
            DataStructures.get_data_structure_by_external_id(data_structure_external_id)},
         {:can, true} <- {:can, can?(claims, create_grant(data_structure))},
         {:ok, %{grant: %{id: id}}} <-
           Grants.create_grant(grant_params, data_structure, claims, true) do
      reduce_insert_grant(tail, claims, acc ++ [id])
    else
      {:data_structure, nil} ->
        {:error, {:not_found, "DataStructure"}}

      {:error, :grant, err, _} ->
        {:error, err}

      error ->
        {:error, error}
    end
  end

  defp reduce_insert_grant(_, _, _), do: {:error, {:not_found, "op [add] Missing"}}

  defp do_reindex({:ok, %{ids: ids}}) do
    IndexWorker.reindex_grants(ids)
  end

  defp do_reindex(result), do: result
end
