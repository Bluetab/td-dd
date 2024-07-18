defmodule TdDd.Lineage.Import.Loader do
  @moduledoc """
  Provides functions for loading graph data from CSV import format into a
  persistent model backed by Ecto schemas.
  """

  alias Ecto.Multi
  alias TdDd.Lineage.Import.Reader
  alias TdDd.Lineage.Import.Validations
  alias TdDd.Lineage.Units
  alias TdDd.Lineage.Units.Edge
  alias TdDd.Lineage.Units.Node
  alias TdDd.Repo

  require Logger

  ## Client API

  def load(unit, nodes_path, rels_path, opts) do
    Units.insert_event(unit, "LoadStarted")
    do_load(unit, nodes_path, rels_path, opts)
  end

  ## Private functions

  defp do_load(unit, nodes_path, rels_path, opts) do
    case Reader.read(nodes_path, rels_path, opts) do
      {:ok, graph} ->
        do_load(unit, graph)

      %Validations{valid: false} = validations ->
        Logger.warn("Validations failed for unit #{unit.name}")
        Units.insert_event(unit, "LoadFailed", Validations.to_map(validations))

      {:error, %{} = info} = error ->
        Logger.warn("Error reading unit #{unit.name}: #{inspect(info)}")
        Units.insert_event(unit, "LoadFailed", info)
        error

      error ->
        Logger.warn("Error reading unit #{unit.name}: #{inspect(error)}")
        Units.insert_event(unit, "LoadFailed")
        error
    end
  end

  defp do_load(unit, graph) do
    Multi.new()
    |> Multi.run(:graph, fn _, _ -> {:ok, graph} end)
    |> Multi.run(:unit, fn _, _ -> {:ok, unit} end)
    |> Multi.run(:upsert_nodes, fn _, _ -> upsert_nodes(graph) end)
    |> Multi.run(:node_map, fn _, %{upsert_nodes: {_, nodes}} ->
      {:ok, Map.new(nodes, fn %{id: id, external_id: external_id} -> {external_id, id} end)}
    end)
    |> Multi.run(:upsert_unit_nodes, &upsert_unit_nodes/2)
    |> Multi.run(:upsert_edges, &upsert_edges/2)
    |> Multi.run(:link, fn _, %{unit: unit} -> Units.link_nodes(unit_id: unit.id) end)
    |> Repo.transaction()
    |> on_complete()
  end

  defp upsert_nodes(%Graph{} = graph) do
    ts = DateTime.utc_now()

    Repo.transaction(fn ->
      entries =
        graph
        |> Graph.vertices(labels: true)
        |> Enum.map(fn {external_id, label} ->
          {class, label} = Map.pop!(label, :class)

          %{
            external_id: external_id,
            label: label,
            type: class,
            deleted_at: nil,
            updated_at: ts,
            inserted_at: ts
          }
        end)

      chunk_size = Application.get_env(:td_dd, __MODULE__)[:nodes_chunk_size]

      {count, nodes} =
        Repo.chunk_insert_all(Node, entries,
          chunk_size: chunk_size,
          conflict_target: [:external_id],
          on_conflict: {:replace, [:external_id, :type, :label, :updated_at, :deleted_at]},
          returning: [:id, :external_id]
        )

      Logger.debug("Upserted #{count} nodes")

      {count, nodes}
    end)
  end

  defp upsert_edges(_repo, %{node_map: node_map, graph: graph, unit: %{id: unit_id}}) do
    ts = DateTime.utc_now()

    Repo.transaction(fn ->
      entries =
        graph
        |> Graph.get_edges()
        |> Enum.map(fn %{v1: v1, v2: v2, label: %{class: class, metadata: metadata}} ->
          %{
            unit_id: unit_id,
            start_id: Map.fetch!(node_map, v1),
            end_id: Map.fetch!(node_map, v2),
            type: class,
            metadata: metadata,
            inserted_at: ts,
            updated_at: ts
          }
        end)

      chunk_size = Application.get_env(:td_dd, __MODULE__)[:edges_chunk_size]

      {count, edges} =
        Repo.chunk_insert_all(Edge, entries,
          chunk_size: chunk_size,
          conflict_target: [:unit_id, :start_id, :end_id],
          on_conflict: {:replace, [:type, :updated_at]},
          returning: [:id]
        )

      Logger.debug("Upserted #{count} edges")

      {count, edges}
    end)
  end

  defp upsert_unit_nodes(_repo, %{unit: %{id: unit_id}, node_map: node_map}) do
    Repo.transaction(fn ->
      entries =
        node_map
        |> Map.values()
        |> Enum.map(fn node_id -> %{node_id: node_id, unit_id: unit_id, deleted_at: nil} end)

      chunk_size = Application.get_env(:td_dd, __MODULE__)[:units_chunk_size]

      {count, node_ids} =
        Repo.chunk_insert_all("units_nodes", entries,
          chunk_size: chunk_size,
          conflict_target: [:unit_id, :node_id],
          on_conflict: {:replace, [:deleted_at]},
          returning: [:node_id]
        )

      Logger.debug("Upserted #{count} units_nodes")

      {count, node_ids}
    end)
  end

  defp on_complete(result) do
    case result do
      {:ok, %{graph: graph, link: links, unit: %{name: name} = unit}} ->
        nodes = Graph.no_vertices(graph)
        edges = Graph.no_edges(graph)

        Units.insert_event(unit, "LoadSucceeded", %{
          node_count: nodes,
          edge_count: edges,
          links_added: links
        })

        Logger.info("Load succeeded unit=#{name} #{nodes} nodes #{edges} edges +#{links} links")

      {:error, failed_operation, _failed_value, %{unit: unit}} ->
        Units.insert_event(unit, "LoadFailed", %{failed_operation: failed_operation})
        Logger.warn("Load failed on #{failed_operation}")

      _ ->
        :ignore
    end

    result
  end
end
