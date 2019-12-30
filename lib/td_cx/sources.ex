defmodule TdCx.Sources do
  @moduledoc """
  The Sources context.
  """

  import Ecto.Query, warn: false
  alias TdCx.Repo

  alias TdCx.Sources.Source

  require Logger

  @doc """
  Returns the list of sources.

  ## Examples

      iex> list_sources()
      [%Source{}, ...]

  """
  def list_sources do
    Repo.all(Source)
  end

  def list_sources_by_source_type(source_type) do
    Source
    |> where([s], s.type == ^source_type)
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
  def get_source!(external_id) do
    Repo.get_by!(Source, external_id: external_id)
  end

  def enrich_secrets(%Source{secrets_key: nil} = source) do
    source
  end

  def enrich_secrets(source) do
    secrets = read_secrets(source.secrets_key)
    Map.put(source, :secrets, secrets)
  end

  @doc """
  Creates a source.

  ## Examples

      iex> create_source(%{field: value})
      {:ok, %Source{}}

      iex> create_source(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_source(%{"secrets" => secrets, "external_id" => external_id, "type" => type} = attrs) do

    secrets_key = build_secret_key(type, external_id)

    with {:ok, _r} <- write_secrets(secrets_key, secrets) do
      attrs =
        attrs
        |> Map.put("secrets_key", secrets_key)
        |> Map.drop(["secrets"])

      %Source{}
      |> Source.changeset(attrs)
      |> Repo.insert()
    else
      {:error, error} ->
        Logger.error(error)
        {:error, "Error storing secrets"}
    end
  end

  def create_source(attrs) do
    %Source{}
    |> Source.changeset(attrs)
    |> Repo.insert()
  end

  defp build_secret_key(type, external_id) do
    "#{type}/#{external_id}"
  end

  defp write_secrets(secrets_key, secrets) do
    vault_config = Application.get_env(:td_cx, :vault)
    token = vault_config[:token]
    secrets_path = vault_config[:secrets_path]

    Vaultex.Client.write(
      "#{secrets_path}#{secrets_key}",
      %{"data" => %{"value" => secrets}},
      :token,
      {token}
    )
  end

  defp read_secrets(secrets_key) do
    vault_config = Application.get_env(:td_cx, :vault)
    token = vault_config[:token]
    secrets_path = vault_config[:secrets_path]

    {:ok, %{"data" => %{"value" => value}}} =
      Vaultex.Client.read("#{secrets_path}#{secrets_key}", :token, {token})

    value
  end

  @doc """
  Updates a source.

  ## Examples

      iex> update_source(source, %{field: new_value})
      {:ok, %Source{}}

      iex> update_source(source, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_source(
        %Source{type: type, external_id: external_id} = source,
        %{"secrets" => secrets, "config" => _config} = attrs
      ) do
    secrets_key = build_secret_key(type, external_id)

    with {:ok, _r} <- write_secrets(secrets_key, secrets) do
      attrs =
        attrs
        |> Map.put("secrets_key", secrets_key)
        |> Map.drop(["secrets", "type", "external_id"])

      source
      |> Source.changeset(attrs)
      |> Repo.update()
    else
      {:error, error} ->
        Logger.error(error)
        {:error, "Error storing secrets"}
    end
  end

  def update_source(%Source{} = source, %{"config" => _config} = attrs) do
    updateable_attrs = Map.drop(attrs, ["secrets", "type", "external_id"])

    source
    |> Source.changeset(updateable_attrs)
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
  def delete_source(%Source{} = source) do
    Repo.delete(source)
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
