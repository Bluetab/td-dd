defmodule TdCx.Configurations do
  @moduledoc """
  The Configurations context.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias TdCache.TemplateCache
  alias TdCx.Configurations.Configuration
  alias TdCx.Vault
  alias TdDd.Repo

  defdelegate authorize(action, user, params), to: __MODULE__.Policy

  @doc """
  Returns the list of configurations.

  ## Examples

      iex> list_configurations(%Claims{})
      [%Configuration{}, ...]

  """
  def list_configurations(claims, clauses \\ %{}) do
    clauses
    |> Enum.reduce(Configuration, fn
      {:type, type}, q -> where(q, [c], c.type == ^type)
      {"type", type}, q -> where(q, [c], c.type == ^type)
      _, q -> q
    end)
    |> Repo.all()
    |> enrich_secrets(claims)
  end

  @doc """
  Gets a single configuration by external_id and enriches it with
  secrets stored un vault.

  Raises `Ecto.NoResultsError` if the Configuration does not exist.

  ## Examples

      iex> get_configuration_by_external_id!(%Claims{}, 123)
      %Configuration{}

      iex> get_configuration_by_external_id!(%Claims{}, 456)
      ** (Ecto.NoResultsError)

  """
  def get_configuration_by_external_id!(claims, external_id) do
    external_id
    |> get_configuration_by_external_id!()
    |> enrich_secrets(claims)
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
  def get_configuration_by_external_id!(external_id) do
    Repo.get_by!(Configuration, external_id: external_id)
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

  def sign(%Configuration{secrets_key: nil}, _payload), do: {:error, :unauthorized}

  def sign(%Configuration{} = configuration, payload) do
    configuration
    |> do_enrich_secrets()
    |> case do
      {:vault_error, _} = error ->
        error

      configuration ->
        configuration
        |> Map.get(:content)
        |> do_sign(payload)
    end
  end

  defp enrich_secrets([_ | _] = configurations, claims) do
    Enum.map(configurations, &enrich_secrets(&1, claims))
  end

  defp enrich_secrets(%Configuration{secrets_key: nil} = configuration, _claims),
    do: configuration

  defp enrich_secrets(%Configuration{} = configuration, claims) do
    case Bodyguard.permit(__MODULE__, :view_secrets, claims, configuration) do
      :ok -> do_enrich_secrets(configuration)
      _ -> configuration
    end
  end

  defp enrich_secrets(configuration, _claims), do: configuration

  defp do_enrich_secrets(
         %Configuration{secrets_key: secrets_key, content: content} = configuration
       ) do
    secrets = Vault.read_secrets(secrets_key)

    case secrets do
      {:error, msg} ->
        {:vault_error, msg}

      _ ->
        secrets = secrets || %{}
        Map.put(configuration, :content, Map.merge(content || %{}, secrets))
    end
  end

  defp do_sign(%{"secret_key" => key}, %{} = jwt) when is_binary(key) do
    jws = %{"alg" => "HS256", "typ" => "JWT"}
    k = Base.encode64(key)

    token =
      %{"k" => k, "kty" => "oct"}
      |> JOSE.JWT.sign(jws, jwt)
      |> JOSE.JWS.compact()
      |> elem(1)

    {:ok, token}
  end

  defp do_sign(_, _), do: {:error, :unauthorized}

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

  defp create_secrets(%{
         base: %{changes: %{type: type, external_id: external_id, content: content}}
       }) do
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
      {:vault_error, error} -> {:error, error}
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
    import Ecto.Changeset, only: [get_field: 2]
    external_id = get_field(changeset, :external_id)
    type = get_field(changeset, :type)

    {_secrets, content} = Map.split(content, secrets)

    changeset
    |> Configuration.update_config(content)
    |> Configuration.update_secrets_key(secrets_key(type, external_id))
  end

  defp do_update(%{base: changeset}), do: changeset

  defp secrets_key(type, external_id) do
    "config/#{type}/#{external_id}"
  end
end
