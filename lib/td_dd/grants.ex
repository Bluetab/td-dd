defmodule TdDd.Grants do
  @moduledoc """
  The Grants context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias TdDd.Auth.Claims
  alias TdDd.DataStructures.Audit
  alias TdDd.Repo

  alias TdDd.Grants.Grant

  @doc """
  Returns the list of grants.

  ## Examples

      iex> list_grants(%{user_id: 1})
      [%Grant{}, ...]

  """
  def list_grants(params \\ %{}) do
    params
    |> Enum.reduce(Grant, fn
      {:user_id, user_id}, q ->
        where(q, [g], g.user_id == ^user_id)
    end)
    |> Repo.all()
  end

  @doc """
  Gets a single grant.

  Raises `Ecto.NoResultsError` if the Grant does not exist.

  ## Examples

      iex> get_grant!(123)
      %Grant{}

      iex> get_grant!(456)
      ** (Ecto.NoResultsError)

  """
  def get_grant!(id, opts \\ []) do
    Grant
    |> Repo.get!(id)
    |> Repo.preload(opts[:preload] || [])
  end

  @doc """
  Creates a grant.

  ## Examples

      iex> create_grant(%{field: value}, %DataStructure{}, %Claims{user_id: user_id})
      {:ok, %Grant{}}

      iex> create_grant(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_grant(attrs, data_structure, %Claims{user_id: user_id}) do
    changeset = Grant.changeset(attrs, data_structure)

    Multi.new()
    |> Multi.insert(:grant, changeset)
    |> Multi.run(:audit, Audit, :grant_created, [changeset, user_id])
    |> Repo.transaction()
  end

  @doc """
  Updates a grant.

  ## Examples

      iex> update_grant(grant, %{field: new_value})
      {:ok, %Grant{}}

      iex> update_grant(grant, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_grant(%Grant{} = grant, attrs, %Claims{user_id: user_id}) do
    changeset = Grant.update_changeset(grant, attrs)

    Multi.new()
    |> Multi.update(:grant, changeset)
    |> Multi.run(:audit, Audit, :grant_updated, [changeset, user_id])
    |> Repo.transaction()
  end

  @doc """
  Deletes a grant.

  ## Examples

      iex> delete_grant(grant)
      {:ok, %Grant{}}

      iex> delete_grant(grant)
      {:error, %Ecto.Changeset{}}

  """
  def delete_grant(%Grant{} = grant, %Claims{user_id: user_id}) do
    Multi.new()
    |> Multi.delete(:grant, grant)
    |> Multi.run(:audit, Audit, :grant_deleted, [user_id])
    |> Repo.transaction()
  end
end
