defmodule TdCx.Sources do
  @moduledoc """
  The Sources context.
  """

  import Ecto.Query, warn: false
  alias TdCache.TemplateCache
  alias TdCx.Cache.SourceLoader
  alias TdCx.Repo
  alias TdCx.Sources.Source
  alias TdCx.Vault
  alias TdDfLib.Format
  alias TdDfLib.Validation

  import Canada, only: [can?: 2]

  require Logger

  @doc """
  Returns the list of sources.

  ## Examples

      iex> list_sources()
      [%Source{}, ...]

  """
  def list_sources(options \\ []) do
    Source
    |> with_deleted(options, dynamic([s], is_nil(s.deleted_at)))
    |> Repo.all()
  end

  defp with_deleted(query, options, dynamic) when is_list(options) do
    include_deleted = Keyword.get(options, :deleted, true)
    with_deleted(query, include_deleted, dynamic)
  end

  defp with_deleted(query, true, _), do: query

  defp with_deleted(query, _false, dynamic) do
    where(query, ^dynamic)
  end

  def list_sources_by_source_type(source_type) do
    Source
    |> where([s], s.type == ^source_type)
    |> where([s], s.active == true)
    |> where([s], is_nil(s.deleted_at))
    |> Repo.all()
  end

  @doc """
  Gets a single source.

  Raises `Ecto.NoResultsError` if the Source does not exist.

  ## Examples

      iex> get_source!(123)
      %Source{}

      iex> get_source!(456)
      ** (Ecto.NoResultsError)

  """
  def get_source!(external_id, options \\ []) do
    Source
    |> where([s], s.external_id == ^external_id)
    |> where([s], is_nil(s.deleted_at))
    |> Repo.one!()
    |> enrich(options)
  end

  def enrich_secrets(user, %Source{} = source) do
    case can?(user, view_secrets(source)) do
      true -> enrich_secrets(source)
      _ -> source
    end
  end

  def enrich_secrets(%Source{secrets_key: nil} = source) do
    source
  end

  def enrich_secrets(source) do
    secrets = Vault.read_secrets(source.secrets_key)

    case secrets do
      {:error, msg} ->
        {:error, msg}

      _ ->
        Map.put(source, :config, Map.merge(Map.get(source, :config, %{}) || %{}, secrets || %{}))
    end
  end

  defp enrich(%Source{} = source, []), do: source

  defp enrich(%Source{} = source, options) do
    Repo.preload(source, options)
  end

  @doc """
  Creates a source.

  ## Examples

      iex> create_source(%{field: value})
      {:ok, %Source{}}

      iex> create_source(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_source(attrs \\ %{}) do
    with {:ok} <- check_base_changeset(attrs),
         {:ok} <- is_valid_template_content(attrs) do
      %{"secrets" => secrets, "config" => config} = separate_config(attrs)

      attrs
      |> Map.put("secrets", secrets)
      |> Map.put("config", config)
      |> do_create_source()
      |> on_upsert()
    else
      error ->
        error
    end
  end

  defp separate_config(%{"config" => config, "type" => type}) do
    %{:content => content_schema} = TemplateCache.get_by_name!(type)

    secret_keys =
      content_schema
      |> Enum.filter(fn group -> Map.get(group, "is_secret") == true end)
      |> Enum.map(fn group -> Map.get(group, "fields") end)
      |> List.flatten()
      |> Enum.map(fn field -> Map.get(field, "name") end)

    {secrets, config} = Map.split(config, secret_keys)
    %{"secrets" => secrets, "config" => config}
  end

  defp do_create_source(%{"secrets" => secrets} = attrs) when secrets == %{} do
    %Source{}
    |> Source.changeset(attrs)
    |> Repo.insert()
  end

  defp do_create_source(
         %{"secrets" => secrets, "external_id" => external_id, "type" => type} = attrs
       ) do
    secrets_key = build_secret_key(type, external_id)

    case Vault.write_secrets(secrets_key, secrets) do
      :ok ->
        attrs =
          attrs
          |> Map.put("secrets_key", secrets_key)
          |> Map.drop(["secrets"])

        %Source{}
        |> Source.changeset(attrs)
        |> Repo.insert()

      error ->
        error
    end
  end

  defp do_create_source(attrs) do
    %Source{}
    |> Source.changeset(attrs)
    |> Repo.insert()
  end

  defp check_base_changeset(attrs, source \\ %Source{}) do
    changeset = Source.changeset(source, attrs)

    case changeset.valid? do
      true -> {:ok}
      false -> {:error, changeset}
    end
  end

  defp is_valid_template_content(%{"type" => type, "config" => config} = _attrs)
       when not is_nil(type) do
    %{:content => content_schema} = TemplateCache.get_by_name!(type)
    content_schema = Format.flatten_content_fields(content_schema)
    content_changeset = Validation.build_changeset(config, content_schema)

    case content_changeset.valid? do
      true -> {:ok}
      false -> {:error, content_changeset}
    end
  end

  defp build_secret_key(type, external_id) do
    "#{type}/#{external_id}"
  end

  @doc """
  Updates a source.

  ## Examples

      iex> update_source(source, %{field: new_value})
      {:ok, %Source{}}

      iex> update_source(source, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_source(%Source{} = source, %{"config" => config} = attrs) do
    with {:ok} <- check_base_changeset(attrs, source),
         {:ok} <-
           is_valid_template_content(%{
             "type" => Map.get(source, :type),
             "config" => config
           }) do
      %{"secrets" => secrets, "config" => config} =
        separate_config(%{"type" => Map.get(source, :type), "config" => config})

      attrs =
        attrs
        |> Map.put("secrets", secrets)
        |> Map.put("config", config)

      source
      |> do_update_source(attrs)
      |> on_upsert()
    else
      error ->
        error
    end
  end

  def update_source(%Source{} = source, attrs) do
    source
    |> Source.changeset(attrs)
    |> Repo.update()
    |> on_upsert()
  end

  defp do_update_source(%Source{} = source, %{"secrets" => secrets} = attrs)
       when secrets == %{} do
    updateable_attrs = Map.drop(attrs, ["secrets", "type", "external_id"])
    updateable_attrs = Map.put(updateable_attrs, "secrets_key", nil)

    case Vault.delete_secrets(source.secrets_key) do
      :ok ->
        source
        |> Source.changeset(updateable_attrs)
        |> Repo.update()

      {:vault_error, error} ->
        {:vault_error, error}
    end
  end

  defp do_update_source(
         %Source{type: type, external_id: external_id} = source,
         %{"secrets" => secrets} = attrs
       ) do
    secrets_key = build_secret_key(type, external_id)

    case Vault.write_secrets(secrets_key, secrets) do
      :ok ->
        attrs =
          attrs
          |> Map.put("secrets_key", secrets_key)
          |> Map.drop(["secrets", "type", "external_id"])

        source
        |> Source.changeset(attrs)
        |> Repo.update()

      error ->
        error
    end
  end

  defp do_update_source(%Source{} = source, %{"config" => config}) do
    source
    |> Source.changeset(%{"config" => config})
    |> Repo.update()
  end

  defp on_upsert({:ok, %Source{id: id, deleted_at: deleted_at}} = result)
       when not is_nil(deleted_at) do
    SourceLoader.delete(id)
    result
  end

  defp on_upsert({:ok, %Source{external_id: external_id}} = result) do
    SourceLoader.refresh(external_id)
    result
  end

  defp on_upsert(result), do: result

  @doc """
  Deletes a Source.

  ## Examples

      iex> delete_source(source)
      {:ok, %Source{}}

      iex> delete_source(source)
      {:error, %Ecto.Changeset{}}

  """
  def delete_source(%Source{secrets_key: secrets_key} = source) do
    with {:ok, source} <- do_delete_source(source),
         _v <- Vault.delete_secrets(secrets_key) do
      on_delete({:ok, source})
    end
  end

  defp do_delete_source(%Source{external_id: external_id, jobs: %Ecto.Association.NotLoaded{}}) do
    external_id
    |> get_source!([:jobs])
    |> do_delete_source()
  end

  defp do_delete_source(%Source{jobs: jobs} = source) when jobs == [] do
    source
    |> Source.delete_changeset()
    |> Repo.delete()
  end

  defp do_delete_source(%Source{jobs: jobs} = source) when length(jobs) > 0 do
    update_source(source, %{deleted_at: DateTime.utc_now()})
  end

  defp on_delete(res) do
    with {:ok, %Source{id: id} = _} <- res do
      SourceLoader.delete(id)
      res
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking source changes.

  ## Examples

      iex> change_source(source)
      %Ecto.Changeset{source: %Source{}}

  """
  def change_source(%Source{} = source) do
    Source.changeset(source, %{})
  end
end
