defmodule TdDd.Cache.StructureEntry do
  @moduledoc """
  Cache representation of data structures.
  """

  alias Ecto.Association.NotLoaded
  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.Repo

  @spec cache_entry(nil | integer | DataStructureVersion.t(), Keyword.t()) :: map
  def cache_entry(target, opts \\ [])

  def cache_entry(nil, _opts), do: %{}

  def cache_entry(structure_id, opts) when is_integer(structure_id) do
    structure_id
    |> DataStructures.get_latest_version()
    |> cache_entry(opts)
  end

  def cache_entry(%DataStructureVersion{data_structure_id: id, data_structure: ds} = dsv, opts) do
    %{external_id: external_id, system_id: system_id, domain_id: domain_id} = ds

    acc =
      dsv
      |> Map.take([:group, :name, :type, :metadata, :updated_at, :deleted_at, :path])
      |> Map.put(:id, id)
      |> Map.update(:path, [], fn path -> Enum.map(path, & &1["name"]) end)
      |> Map.put(:external_id, external_id)
      |> Map.put(:system_id, system_id)
      |> Map.put(:domain_id, domain_id)
      |> Map.put(:parent_id, get_first_parent_id(dsv))

    Enum.reduce(opts, acc, &put_cache_opt(ds, &1, &2))
  end

  @spec get_first_parent_id(DataStructureVersion.t()) :: nil | non_neg_integer
  defp get_first_parent_id(dsv)
  defp get_first_parent_id(%{parents: nil}), do: nil
  defp get_first_parent_id(%{parents: []}), do: nil
  defp get_first_parent_id(%{parents: [%{data_structure_id: id} | _]}), do: id

  defp get_first_parent_id(%{parents: %NotLoaded{}} = dsv) do
    dsv
    |> Repo.preload(:parents)
    |> get_first_parent_id()
  end

  @spec put_cache_opt(DataStructure.t(), {atom, any}, map) :: map
  defp put_cache_opt(dsv, option, acc)

  defp put_cache_opt(dsv, {:system, true}, %{} = acc) do
    put_cache_opt(dsv, {:system, [:id, :name, :external_id]}, acc)
  end

  defp put_cache_opt(%{system: nil}, {:system, _}, %{} = acc), do: acc

  defp put_cache_opt(%{system: %{id: _} = system}, {:system, keys}, %{} = acc) do
    Map.put(acc, :system, Map.take(system, keys))
  end

  defp put_cache_opt(%{system: %NotLoaded{}} = dsv, {:system, _} = opt, acc) do
    dsv
    |> Repo.preload(:system)
    |> put_cache_opt(opt, acc)
  end
end
