defmodule TdDd.ProfilingLoader do
  @moduledoc """
  Bulk loader for profiles
  """

  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.Profiles
  alias TdDd.Repo

  require Logger

  def load(profile_records) do
    profile_count = Enum.count(profile_records)
    Logger.info("Starting bulk load (#{profile_count}PR")
    Repo.transaction(fn -> do_load(profile_records) end)
  end

  defp do_load(profile_records) do
    case upsert_profiles(profile_records) do
      {:ok, results} -> results
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
        |> Map.merge(Map.take(attrs, [:value]))
        |> Profiles.create_profile()

      %DataStructure{profile: profile} ->
        Profiles.update_profile(profile, Map.take(attrs, [:value]))

      nil ->
        {:error,
         %{
           errors: [
             external_id:
               {"Missing structure with external_id #{Map.get(attrs, :external_id)}", []}
           ]
         }}
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
