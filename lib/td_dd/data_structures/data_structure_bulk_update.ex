defmodule TdDd.DataStructures.BulkUpdate do
  @moduledoc false
  require Logger

  alias TdDd.DataStructures
  alias TdDd.Repo
  alias TdDd.Search.IndexWorker

  def update_all(user, data_structures, %{"df_content" => content}) do
    data_structures =
      data_structures
      |> Enum.map(&DataStructures.get_data_structure!(&1.id))

    update_attributes =
      %{}
      |> Map.put("df_content", content)
      |> Map.put("last_change_by", user.id)

    case update(data_structures, update_attributes) do
      {:ok, ds_list} -> {:ok, ds_list |> Enum.map(& &1.id)}
      error -> error
    end
  end

  defp update(data_structures, update_attributes) do
    Logger.info("Updating data structures...")

    Timer.time(
      fn -> update_in_transaction(data_structures, update_attributes) end,
      fn ms, _ ->
        "Data structures updated in #{ms}ms"
      end
    )
  end

  defp update_in_transaction(data_structures, update_attributes) do
    Repo.transaction(fn ->
      case update_data(data_structures, update_attributes, []) do
        {:ok, ds_list} ->
          ds_list

        {:error, err} ->
          Repo.rollback(err)
      end
    end)
    |> reindex()
  end

  defp reindex({:ok, data_structures}) do
    data_structures
    |> Enum.map(& &1.id)
    |> IndexWorker.reindex()

    {:ok, data_structures}
  end

  defp reindex(errors), do: errors

  defp update_data([head | tail], update_attributes, acc) do
    case DataStructures.update_data_structure(head, update_attributes, bulk: true) do
      {:ok, ds} ->
        update_data(tail, update_attributes, [ds | acc])

      error ->
        error
    end
  end

  defp update_data(_, _, acc), do: {:ok, acc}
end
