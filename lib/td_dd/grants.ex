defmodule TdDd.Grants do
  @moduledoc """
  The Grants context.
  """

  import Ecto.Query, warn: false
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
  def get_grant!(id), do: Repo.get!(Grant, id)

  @doc """
  Creates a grant.

  ## Examples

      iex> create_grant(%{field: value})
      {:ok, %Grant{}}

      iex> create_grant(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_grant(attrs, data_structure) do
    %Grant{}
    |> Grant.changeset(attrs, data_structure)
    |> Repo.insert()
  end

  @doc """
  Updates a grant.

  ## Examples

      iex> update_grant(grant, %{field: new_value})
      {:ok, %Grant{}}

      iex> update_grant(grant, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_grant(%Grant{} = grant, attrs) do
    grant
    |> Grant.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a grant.

  ## Examples

      iex> delete_grant(grant)
      {:ok, %Grant{}}

      iex> delete_grant(grant)
      {:error, %Ecto.Changeset{}}

  """
  def delete_grant(%Grant{} = grant) do
    Repo.delete(grant)
  end
end
