defmodule TdCx.Configurations do
  @moduledoc """
  The Configurations context.
  """

  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias TdCache.TemplateCache
  alias TdCx.Configurations.Configuration
  alias TdCx.Repo
  alias TdCx.Vault

  @doc """
  Returns the list of configurations.

  ## Examples

      iex> list_configurations()
      [%Configuration{}, ...]

  """
  def list_configurations(clauses \\ %{}, opts \\ []) do
    clauses
    |> Enum.reduce(Configuration, fn
      {:type, type}, q -> where(q, [c], c.type == ^type)
    end)
    |> Repo.all()
    |> enrich(opts)
  end

  @doc """
  Gets a single configuration.

  Raises `Ecto.NoResultsError` if the Configuration does not exist.

  ## Examples

      iex> get_configuration!(123)
      %Configuration{}

      iex> get_configuration!(456)
      ** (Ecto.NoResultsError)

  """
  def get_configuration!(id, opts \\ []) do
    Configuration
    |> Repo.get!(id)
    |> enrich(opts)
  end

  @doc """
  Gets a single configuration by external_id.

  Raises `Ecto.NoResultsError` if the Configuration does not exist.

  ## Examples

      iex> get_configuration_by_external_id!(123)
      %Configuration{}

      iex> get_configuration_by_external_id!(456)
      ** (Ecto.NoResultsError)

  """
  def get_configuration_by_external_id!(external_id, opts \\ []) do
    Configuration
    |> Repo.get_by!(external_id: external_id)
    |> enrich(opts)
  end

  @doc """
  Creates a configuration.

  ## Examples

      iex> create_configuration(%{field: value})
      {:ok, %Configuration{}}

      iex> create_configuration(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_configuration(attrs \\ %{}) do
    Multi.new()
    |> Multi.run(:base, fn _, _ -> changeset(attrs) end)
    |> Multi.run(:secrets, fn _, changes -> create_secrets(changes) end)
    |> Multi.insert(:configuration, fn changes -> do_insert(changes) end)
    |> Repo.transaction()
    |> case do
      {:ok, %{configuration: configuration}} ->
        {:ok, configuration}

      {:error, _, changeset, _} ->
        {:error, changeset}
    end
  end

  @doc """
  Updates a configuration.

  ## Examples

      iex> update_configuration(configuration, %{field: new_value})
      {:ok, %Configuration{}}

      iex> update_configuration(configuration, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_configuration(%Configuration{} = configuration, attrs) do
    Multi.new()
    |> Multi.run(:base, fn _, _ -> update_changeset(configuration, attrs) end)
    |> Multi.run(:secrets, fn _, changes -> update_secrets(configuration, changes) end)
    |> Multi.update(:configuration, fn changes -> do_update(changes) end)
    |> Repo.transaction()
    |> case do
      {:ok, %{configuration: configuration}} ->
        {:ok, configuration}

      {:error, _, changeset, _} ->
        {:error, changeset}
    end
  end

  @doc """
  Deletes a configuration.

  ## Examples

      iex> delete_configuration(configuration)
      {:ok, %Configuration{}}

      iex> delete_configuration(configuration)
      {:error, %Ecto.Changeset{}}

  """
  def delete_configuration(%Configuration{secrets_key: secrets_key} = configuration) do
    Vault.delete_secrets(secrets_key)
    Repo.delete(configuration)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking configuration changes.

  ## Examples

      iex> change_configuration(configuration)
      %Ecto.Changeset{data: %Configuration{}}

  """
  def change_configuration(%Configuration{} = configuration, attrs \\ %{}) do
    Configuration.changeset(configuration, attrs)
  end

  defp enrich([_ | _] = configurations, [_ | _] = opts) do
    Enum.map(configurations, &enrich(&1, opts))
  end

  defp enrich(%Configuration{} = configuration, [_ | _] = opts) do
    Enum.reduce(opts, configuration, &with_attr/2)
  end

  defp enrich(configuration, _opts), do: configuration

  defp with_attr(:secrets, %Configuration{secrets_key: nil} = configuration), do: configuration

  defp with_attr(
         :secrets,
         %Configuration{secrets_key: secrets_key, content: content} = configuration
       ) do

    secrets = Vault.read_secrets(secrets_key)
    content = content || %{}

    case secrets do
      {:error, msg} ->
        {:error, msg}

      _ ->
        secrets = secrets || %{}
        Map.put(configuration, :content, Map.merge(content, secrets))
    end
  end

  defp with_attr(_attr, configuration), do: configuration

  defp changeset(attrs) do
    changeset = Configuration.changeset(attrs)

    case changeset.valid? do
      true -> {:ok, changeset}
      _ -> {:error, changeset}
    end
  end

  defp update_changeset(configuration, attrs) do
    changeset = Configuration.update_changeset(configuration, attrs)

    case changeset.valid? do
      true -> {:ok, changeset}
      _ -> {:error, changeset}
    end
  end

  defp create_secrets(
         %{base: %{changes: %{type: type, external_id: external_id, content: content}}}
       ) do
      persist_secrets(external_id, type, content)
  end

  defp create_secrets(_changes), do: {:ok, []}

  defp update_secrets(
         %{type: type, external_id: external_id},
         %{base: %{changes: %{content: content}}}
       ) do
      persist_secrets(external_id, type, content)
  end

  defp update_secrets(_config, _changes), do: {:ok, []}

  defp persist_secrets(external_id, type, content) do
    secrets = secret_fields(type)
    key = secrets_key(type, external_id)

    case insert_vault(key, secrets, content) do
      :ok -> {:ok, secrets}
      error -> error
    end
  end

  defp secret_fields(type) do
    %{:content => content} = TemplateCache.get_by_name!(type)

    content
    |> Enum.filter(&Map.get(&1, "is_secret"))
    |> Enum.map(&Map.get(&1, "fields"))
    |> List.flatten()
    |> Enum.map(&Map.get(&1, "name"))
  end

  defp insert_vault(key, [_ | _] = secrets, content) do
    secret_config = Map.take(content, secrets)
    Vault.write_secrets(key, secret_config)
  end

  defp insert_vault(_key, [], _changes), do: :ok

  defp do_insert(%{
         base: %{changes: %{content: content, type: type, external_id: external_id}} = changeset,
         secrets: [_ | _] = secrets
       }) do
    {_secrets, content} = Map.split(content, secrets)

    changeset
    |> Configuration.update_config(content)
    |> Configuration.update_secrets_key(secrets_key(type, external_id))
  end

  defp do_insert(%{base: changeset}), do: changeset

  defp do_update(%{
         base: %{changes: %{content: content}} = changeset,
         secrets: [_ | _] = secrets
       }) do
    {_secrets, content} = Map.split(content, secrets)
    Configuration.update_config(changeset, content)
  end

  defp do_update(%{base: changeset}), do: changeset

  defp secrets_key(type, external_id) do
    "config/#{type}/#{external_id}"
  end
end
