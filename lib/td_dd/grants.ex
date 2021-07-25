defmodule TdDd.Grants do
  @moduledoc """
  The Grants context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Changeset
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

      {:data_structure_id, data_structure_id}, q ->
        where(q, [g], g.data_structure_id == ^data_structure_id)

      {:overlaps, %{start_date: start_date, end_date: nil}}, q ->
        where(q, [g], g.end_date >= ^start_date or is_nil(g.end_date))

      {:overlaps, %{start_date: start_date, end_date: end_date}}, q ->
        where(
          q,
          [g],
          (g.end_date >= ^start_date or is_nil(g.end_date)) and
            g.start_date <= ^end_date
        )
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
    |> Multi.run(:overlap, fn _, _ -> date_range_overlap?(changeset) end)
    |> Multi.insert(:grant, changeset)
    |> Multi.run(:audit, Audit, :grant_created, [changeset, user_id])
    |> Repo.transaction()
  end

  defp date_range_overlap?(%{valid?: true} = changeset) do
    %{id: data_structure_id} = Changeset.get_field(changeset, :data_structure)
    user_id = Changeset.get_field(changeset, :user_id)
    start_date = Changeset.get_field(changeset, :start_date)
    end_date = Changeset.get_field(changeset, :end_date)

    %{
      data_structure_id: data_structure_id,
      user_id: user_id,
      overlaps: %{start_date: start_date, end_date: end_date}
    }
    |> list_grants()
    |> Enum.empty?()
    |> case do
      true -> {:ok, nil}
      false -> {:error, Changeset.add_error(changeset, :date_range, "overlaps")}
    end
  end

  defp date_range_overlap?(_), do: {:ok, nil}

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
