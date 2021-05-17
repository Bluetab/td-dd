defmodule TdCx.Sources do
  @moduledoc """
  The Sources context.
  """

  import Ecto.Query
  import Canada, only: [can?: 2]

  require Logger

  alias TdCache.TemplateCache
  alias TdCx.Auth.Claims
  alias TdCx.Sources.Source
  alias TdCx.Vault
  alias TdDd.Repo
  alias TdDfLib.Format
  alias TdDfLib.Validation

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

  @doc """
  Returns the list of sources.

  ## Examples

      iex> query_sources(%{alias: "foo"})
      [%Source{}, ...]

  """
  def query_sources(params_or_identifier) do
    params_or_identifier
    |> source_query()
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
  def get_source!(params_or_identifier) do
    params_or_identifier
    |> source_query()
    |> Repo.one!()
  end

  def get_source(params_or_identifier) do
    params_or_identifier
    |> source_query()
    |> Repo.one()
  end

  defp source_query(params_or_identifier) do
    params_or_identifier
    |> source_params()
    |> Enum.reduce(Source, fn
      {:external_id, external_id}, q ->
        where(q, [s], s.external_id == ^external_id)

      {:id, id}, q ->
        where(q, [s], s.id == ^id)

      {:preload, preloads}, q ->
        preload(q, ^preloads)

      {:deleted, true}, q ->
        where(q, [s], not is_nil(s.deleted_at))

      {:alias, source_alias}, q ->
        where(q, [s], fragment("(?) @> ?::jsonb", s.config, ^%{alias: source_alias}))

      {:job_types, type}, q ->
        where(q, [s], fragment("(?) @> ?::jsonb", s.config, ^%{job_types: [type]}))
    end)
  end

  defp source_params(nil), do: %{}
  defp source_params(%{} = params), do: params
  defp source_params(external_id) when is_binary(external_id), do: %{external_id: external_id}
  defp source_params(id) when is_integer(id), do: %{id: id}
  defp source_params(list) when is_list(list), do: Map.new(list)

  def enrich_secrets(%Claims{} = claims, %Source{} = source) do
    case can?(claims, view_secrets(source)) do
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
      %{} = secrets ->
        config = Map.get(source, :config) || %{}
        Map.put(source, :config, Map.merge(config, secrets))

      _ ->
        source
    end
  end

  def create_or_update_source(%{"external_id" => external_id} = params) do
    case get_source(external_id: external_id, deleted: true) do
      nil -> create_source(params)
      %Source{} = source -> update_source(source, Map.put_new(params, "deleted_at", nil))
    end
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
    with :ok <- check_base_changeset(attrs),
         :ok <- check_valid_template_content(attrs) do
      %{"secrets" => secrets, "config" => config} = separate_config(attrs)

      attrs
      |> Map.put("secrets", secrets)
      |> Map.put("config", config)
      |> do_create_source()
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
      true -> :ok
      false -> {:error, changeset}
    end
  end

  defp check_valid_template_content(%{"type" => type, "config" => config})
       when not is_nil(type) do
    %{:content => content_schema} = TemplateCache.get_by_name!(type)
    content_schema = Format.flatten_content_fields(content_schema)
    content_changeset = Validation.build_changeset(config, content_schema)

    case content_changeset.valid? do
      true -> :ok
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
    type = Map.get(attrs, "type") || Map.get(source, :type)

    with :ok <- check_base_changeset(attrs, source),
         :ok <- check_valid_template_content(%{"type" => type, "config" => config}) do
      %{"secrets" => secrets, "config" => config} =
        separate_config(%{"type" => type, "config" => config})

      attrs =
        attrs
        |> Map.put("secrets", secrets)
        |> Map.put("config", config)

      do_update_source(source, attrs)
    else
      error -> error
    end
  end

  def update_source(%Source{} = source, attrs) do
    source
    |> Source.changeset(attrs)
    |> Repo.update()
  end

  defp do_update_source(
         %Source{secrets_key: secrets_key} = source,
         %{"secrets" => secrets} = attrs
       )
       when secrets == %{} do
    updateable_attrs =
      attrs
      |> Map.drop(["secrets", "external_id"])
      |> Map.put("secrets_key", nil)

    case Vault.delete_secrets(secrets_key) do
      :ok ->
        source
        |> Source.changeset(updateable_attrs)
        |> Repo.update()

      {:vault_error, error} ->
        {:vault_error, error}
    end
  end

  defp do_update_source(
         %Source{external_id: external_id} = source,
         %{"secrets" => secrets} = attrs
       ) do
    type = Map.get(attrs, "type") || Map.get(source, :type)
    secrets_key = build_secret_key(type, external_id)

    case Vault.write_secrets(secrets_key, secrets) do
      :ok ->
        attrs =
          attrs
          |> Map.put("secrets_key", secrets_key)
          |> Map.drop(["secrets", "external_id"])

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

  @doc """
  Deletes a Source.

  ## Examples

      iex> delete_source(source)
      {:ok, %Source{}}

      iex> delete_source(source)
      {:error, %Ecto.Changeset{}}

  """
  def delete_source(%Source{secrets_key: secrets_key} = source) do
    case do_delete_source(source) do
      {:ok, source} ->
        Vault.delete_secrets(secrets_key)
        {:ok, source}

      error ->
        error
    end
  end

  defp do_delete_source(%Source{external_id: external_id, jobs: %Ecto.Association.NotLoaded{}}) do
    [external_id: external_id, preload: :jobs]
    |> get_source!()
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

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking source changes.

  ## Examples

      iex> change_source(source)
      %Ecto.Changeset{source: %Source{}}

  """
  def change_source(%Source{} = source) do
    Source.changeset(source, %{})
  end

  def job_types(%Claims{} = claims, %Source{} = source) do
    with true <- can?(claims, view_job_types(source)) do
      source
      |> Map.get(:config)
      |> Map.get("job_types", [])
      |> case do
        nil -> []
        job_types -> job_types
      end
      |> Enum.uniq()
    end
  end

  @spec get_aliases(non_neg_integer) :: [binary]
  def get_aliases(source_id) do
    source_id
    |> get_source()
    |> case do
      %{config: %{"alias" => al}} -> [al]
      %{config: %{"aliases" => aliases}} -> aliases
      _ -> []
    end
  end
end
