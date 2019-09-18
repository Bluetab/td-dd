defmodule TdDd.ProfilingLoader do
  @moduledoc """
  Bulk loader for profiles
  """

  import Ecto.Query, warn: false
  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDd.Repo

  require Logger

  def load(profile_records) do
    profile_count = Enum.count(profile_records)
    Logger.info("Starting bulk load (#{profile_count}PR")
    Repo.transaction(fn -> do_load(profile_records) end)
  end

  defp do_load(profile_records) do
    with {:ok, results} <- upsert_profiles(profile_records) do
      results
    else
      {:error, err} -> Repo.rollback(err)
    end
  end

  defp upsert_profiles(_profile_records, acc \\ [])

  defp upsert_profiles([head | tail], acc) do
    case upsert_profile(head) do
      {:ok, %{id: profile_id}} ->
        upsert_profiles(tail, [profile_id | acc])

      error ->
        error
    end
  end

  defp upsert_profiles([], acc), do: {:ok, acc}

  defp upsert_profile(attrs) do
    structure = get_data_structure(attrs)

    case structure do
      %DataStructure{id: id, profile: nil} ->
        Map.new()
        |> Map.put(:data_structure_id, id)
        |> Map.put(:value, Map.drop(attrs, [:external_id]))
        |> DataStructures.create_profile()

      %DataStructure{profile: profile} ->
        value = Map.drop(attrs, [:external_id])
        DataStructures.update_profile(profile, %{value: value})

      nil ->
        {:error, %{error: "Missing structure with external_id #{Map.get(attrs, :external_id)}"}}
    end
  end

  defp get_data_structure(profile) do
    structure = DataStructures.find_data_structure(Map.take(profile, [:external_id]))

    structure =
      unless is_nil(structure) do
        Repo.preload(structure, :profile)
      end

    structure
  end
end
