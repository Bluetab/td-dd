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

  @doc """
  Gets a single source.

  Raises `Ecto.NoResultsError` if the Source does not exist.

  ## Examples

      iex> get_source!(123)
      %Source{}

      iex> get_source!(456)
      ** (Ecto.NoResultsError)

  """
  def get_source!(id), do: Repo.get!(Source, id)

  @doc """
  Creates a source.

  ## Examples

      iex> create_source(%{field: value})
      {:ok, %Source{}}

      iex> create_source(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_source(%{"secrets" => secrets, "external_id" => external_id, "type" => type } = attrs ) do
    IO.inspect attrs
    secrets_key = "#{type}_#{external_id}"

    with {:ok} <- store_secrets(secrets_key, secrets) do
      attrs = attrs
      |> Map.put("secrets_key", secrets_key)
      |> Map.drop("secrets")

      %Source{}
      |> Source.changeset(attrs)
      |> Repo.insert()
    else
      error ->
        Logger.error(
          error
        )
        {:error, "Error storing secrets"}
    end
  end

  def create_source(attrs) do
    %Source{}
    |> Source.changeset(attrs)
    |> Repo.insert()
  end

  defp store_secrets(secrets_key, secrets) do
    token_info = Application.get_env(:td_cx, :vault)
    Vaultex.Client.write(secrets_key, %{"value" => secrets}, :token, {token_info[:token]})
  end

  @doc """
  Updates a source.

  ## Examples

      iex> update_source(source, %{field: new_value})
      {:ok, %Source{}}

      iex> update_source(source, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_source(%Source{} = source, attrs) do
    source
    |> Source.changeset(attrs)
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
