defmodule TdDdWeb.Resolvers.Sources do
  @moduledoc """
  Absinthe resolvers for data sources and related entities
  """

  alias TdCache.TemplateCache
  alias TdCx.Cache.SourcesLatestEvent
  alias TdCx.Sources

  def sources(_parent, args, _resolution) do
    {:ok, Sources.query_sources(args)}
  end

  def source(_parent, args, _resolution) do
    {:ok, Sources.get_source(args)}
  end

  def template(%{type: type}, _args, _resolution) do
    TemplateCache.get_by_name(type)
  end

  def job_types(%{config: config}, _args, _resolution) do
    job_types = Map.get(config, "job_types", [])
    {:ok, job_types}
  end

  def latest_event(%{id: source_id}, _args, _resolution) do
    latest_event = SourcesLatestEvent.get(source_id)
    {:ok, latest_event}
  end

  def enable_source(parent, %{id: id} = _args, resolution) do
    update_source(parent, %{source: %{id: id, active: true}}, resolution)
  end

  def disable_source(parent, %{id: id} = _args, resolution) do
    update_source(parent, %{source: %{id: id, active: false}}, resolution)
  end

  def create_source(_parent, %{source: params} = _args, resolution) do
    params = to_string_keys(params)

    with {:claims, %{} = claims} <- {:claims, claims(resolution)},
         :ok <- Bodyguard.permit(Sources, :create, claims),
         {:ok, %{id: id} = _source} <- Sources.create_source(params) do
      {:ok, Sources.get_source(id: id)}
    else
      {:claims, nil} -> {:error, :unauthorized}
      {:error, error} -> {:error, error}
      {:vault_error, error} -> {:error, error}
    end
  end

  def update_source(_parent, %{source: %{id: id} = params}, resolution) do
    {merge, params} = Map.pop(params, :merge, false)
    params = to_string_keys(params)

    with {:claims, %{} = claims} <- {:claims, claims(resolution)},
         {:source, %{} = source} <- {:source, Sources.get_source(id: id)},
         :ok <- Bodyguard.permit(Sources, :update, claims, source),
         {:ok, _source} <- do_update_source(source, params, merge) do
      {:ok, Sources.get_source(id: id)}
    else
      {:claims, nil} -> {:error, :unauthorized}
      {:source, nil} -> {:error, :not_found}
      {:error, error} -> {:error, error}
      {:vault_error, error} -> {:error, error}
    end
  end

  defp do_update_source(source, params, false), do: Sources.update_source(source, params)

  defp do_update_source(source, %{"config" => params}, true),
    do: Sources.update_source_config(source, params)

  def delete_source(_parent, %{id: id} = _args, resolution) do
    with {:claims, %{} = claims} <- {:claims, claims(resolution)},
         {:source, %{} = source} <- {:source, Sources.get_source(id: id)},
         :ok <- Bodyguard.permit(Sources, :delete, claims, source) do
      Sources.delete_source(source)
    else
      {:claims, nil} -> {:error, :unauthorized}
      {:source, nil} -> {:error, :not_found}
      {:error, error} -> {:error, error}
      {:vault_error, error} -> {:error, error}
    end
  end

  defp claims(%{context: %{claims: claims}}), do: claims
  defp claims(_), do: nil

  # Functions in TdCx.Sources context currently assume string keys
  defp to_string_keys(map), do: Map.new(map, fn {k, v} -> {to_string(k), v} end)
end
