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

  alias TdDd.Grants.GrantRequestGroup

  @doc """
  Returns the list of grant_request_groups.

  ## Examples

      iex> list_grant_request_groups()
      [%GrantRequestGroup{}, ...]

  """
  def list_grant_request_groups do
    Repo.all(GrantRequestGroup)
  end

  def list_grant_request_groups_by_user_id(user_id) do
    GrantRequestGroup
    |> where(user_id: ^user_id)
    |> Repo.all()
  end

  @doc """
  Gets a single grant_request_group.

  Raises `Ecto.NoResultsError` if the Grant request group does not exist.

  ## Examples

      iex> get_grant_request_group!(123)
      %GrantRequestGroup{}

      iex> get_grant_request_group!(456)
      ** (Ecto.NoResultsError)

  """
  def get_grant_request_group!(id) do
    GrantRequestGroup
    |> Repo.get!(id)
    |> Repo.preload(:requests)
  end

  @doc """
  Gets a single grant_request_group.

  Returns nil if the Grant request group does not exist.

  ## Examples

      iex> get_grant_request_group!(123)
      %GrantRequestGroup{}

      iex> get_grant_request_group!(456)
      nil

  """
  def get_grant_request_group(id), do: Repo.get(GrantRequestGroup, id)

  @doc """
  Creates a grant_request_group.

  ## Examples

      iex> create_grant_request_group(%{field: value})
      {:ok, %GrantRequestGroup{}}

      iex> create_grant_request_group(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_grant_request_group(attrs \\ %{}) do
    %GrantRequestGroup{}
    |> GrantRequestGroup.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a grant_request_group.

  ## Examples

      iex> update_grant_request_group(grant_request_group, %{field: new_value})
      {:ok, %GrantRequestGroup{}}

      iex> update_grant_request_group(grant_request_group, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_grant_request_group(%GrantRequestGroup{} = grant_request_group, attrs) do
    grant_request_group
    |> GrantRequestGroup.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a grant_request_group.

  ## Examples

      iex> delete_grant_request_group(grant_request_group)
      {:ok, %GrantRequestGroup{}}

      iex> delete_grant_request_group(grant_request_group)
      {:error, %Ecto.Changeset{}}

  """
  def delete_grant_request_group(%GrantRequestGroup{} = grant_request_group) do
    Repo.delete(grant_request_group)
  end

  alias TdDd.Grants.GrantRequest

  @doc """
  Returns the list of grant_requests.

  ## Examples

      iex> list_grant_requests()
      [%GrantRequest{}, ...]

  """
  def list_grant_requests(grant_request_group_id) do
    GrantRequest
    |> where(grant_request_group_id: ^grant_request_group_id)
    |> Repo.all()
  end

  @doc """
  Gets a single grant_request.

  Raises `Ecto.NoResultsError` if the Grant request does not exist.

  ## Examples

      iex> get_grant_request!(123)
      %GrantRequest{}

      iex> get_grant_request!(456)
      ** (Ecto.NoResultsError)

  """
  def get_grant_request!(id), do: Repo.get!(GrantRequest, id)

  @doc """
  Creates a grant_request.

  ## Examples

      iex> create_grant_request(%{field: value})
      {:ok, %GrantRequest{}}

      iex> create_grant_request(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_grant_request(attrs, grant_request_group, data_structure) do
    attrs
    |> GrantRequest.changeset(grant_request_group, data_structure)
    |> Repo.insert()
  end

  @doc """
  Updates a grant_request.

  ## Examples

      iex> update_grant_request(grant_request, %{field: new_value})
      {:ok, %GrantRequest{}}

      iex> update_grant_request(grant_request, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_grant_request(%GrantRequest{} = grant_request, attrs) do
    grant_request
    |> GrantRequest.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a grant_request.

  ## Examples

      iex> delete_grant_request(grant_request)
      {:ok, %GrantRequest{}}

      iex> delete_grant_request(grant_request)
      {:error, %Ecto.Changeset{}}

  """
  def delete_grant_request(%GrantRequest{} = grant_request) do
    Repo.delete(grant_request)
  end
end
