defmodule TdDd.Grants do
  @moduledoc """
  The Grants context.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias TdDd.Auth.Claims
  alias TdDd.DataStructures
  alias TdDd.DataStructures.Audit
  alias TdDd.DataStructures.DataStructure
  alias TdDd.Grants.Grant
  alias TdDd.Grants.GrantRequest
  alias TdDd.Grants.GrantRequestGroup
  alias TdDd.Repo

  def get_grant!(id, opts \\ []) do
    Grant
    |> Repo.get!(id)
    |> Repo.preload(opts[:preload] || [])
  end

  def create_grant(params, %{id: data_structure_id} = data_structure, %Claims{user_id: user_id}) do
    changeset =
      %Grant{data_structure_id: data_structure_id}
      |> Grant.changeset(params)
      |> Grant.put_data_structure(data_structure)

    Multi.new()
    |> Multi.run(:latest, fn _, _ ->
      {:ok, DataStructures.get_latest_version(data_structure, [:path])}
    end)
    |> Multi.insert(:grant, changeset)
    |> Multi.run(:audit, Audit, :grant_created, [user_id])
    |> Repo.transaction()
  end

  def update_grant(%Grant{} = grant, params, %Claims{user_id: user_id}) do
    changeset = Grant.changeset(grant, params)

    Multi.new()
    |> Multi.update(:grant, changeset)
    |> Multi.run(:audit, Audit, :grant_updated, [changeset, user_id])
    |> Repo.transaction()
  end

  def delete_grant(%Grant{data_structure: data_structure} = grant, %Claims{user_id: user_id}) do
    Multi.new()
    |> Multi.run(:latest, fn _, _ ->
      {:ok, DataStructures.get_latest_version(data_structure, [:path])}
    end)
    |> Multi.delete(:grant, grant)
    |> Multi.run(:audit, Audit, :grant_deleted, [user_id])
    |> Repo.transaction()
  end

  def list_grant_request_groups do
    Repo.all(GrantRequestGroup)
  end

  def list_grant_request_groups_by_user_id(user_id) do
    GrantRequestGroup
    |> where(user_id: ^user_id)
    |> Repo.all()
  end

  def get_grant_request_group!(id) do
    GrantRequestGroup
    |> Repo.get!(id)
    |> Repo.preload(:requests)
  end

  def get_grant_request_group(id), do: Repo.get(GrantRequestGroup, id)

  def create_grant_request_group(%{} = params, %Claims{user_id: user_id}) do
    %GrantRequestGroup{user_id: user_id}
    |> GrantRequestGroup.changeset(params)
    |> Repo.insert()
  end

  def delete_grant_request_group(%GrantRequestGroup{} = grant_request_group) do
    Repo.delete(grant_request_group)
  end

  def list_grant_requests(grant_request_group_id) do
    GrantRequest
    |> where(grant_request_group_id: ^grant_request_group_id)
    |> Repo.all()
  end

  def get_grant_request!(id), do: Repo.get!(GrantRequest, id)

  def create_grant_request(
        params,
        %GrantRequestGroup{id: group_id, type: group_type},
        %DataStructure{id: data_structure_id}
      ) do
    %GrantRequest{
      grant_request_group_id: group_id,
      data_structure_id: data_structure_id
    }
    |> GrantRequest.changeset(params, group_type)
    |> Repo.insert()
  end

  def update_grant_request(%GrantRequest{} = grant_request, params) do
    group_type =
      case Repo.preload(grant_request, :grant_request_group) do
        %{grant_request_group: %{type: group_type}} -> group_type
        _ -> nil
      end

    grant_request
    |> GrantRequest.changeset(params, group_type)
    |> Repo.update()
  end

  def delete_grant_request(%GrantRequest{} = grant_request) do
    Repo.delete(grant_request)
  end

  def list_grants(clauses) do
    clauses
    |> Map.new()
    |> Map.put_new(:date, Date.utc_today())
    |> Enum.reduce(Grant, fn
      {:data_structure_ids, ids}, q ->
        where(q, [g], g.data_structure_id in ^ids)

      {:user_id, user_id}, q ->
        where(q, [g], g.user_id == ^user_id)

      {:date, date}, q ->
        where(
          q,
          [g],
          fragment("daterange(?, ?, '[]') @> ?::date", g.start_date, g.end_date, ^date)
        )

      {:preload, preloads}, q ->
        preload(q, ^preloads)
    end)
    |> Repo.all()
  end

  alias TdDd.Grants.GrantApprover

  @doc """
  Returns the list of grant_approvers.

  ## Examples

      iex> list_grant_approvers()
      [%GrantApprover{}, ...]

  """
  def list_grant_approvers do
    Repo.all(GrantApprover)
  end

  @doc """
  Gets a single grant_approver.

  Raises `Ecto.NoResultsError` if the Grant approver does not exist.

  ## Examples

      iex> get_grant_approver!(123)
      %GrantApprover{}

      iex> get_grant_approver!(456)
      ** (Ecto.NoResultsError)

  """
  def get_grant_approver!(id), do: Repo.get!(GrantApprover, id)

  @doc """
  Creates a grant_approver.

  ## Examples

      iex> create_grant_approver(%{field: value})
      {:ok, %GrantApprover{}}

      iex> create_grant_approver(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_grant_approver(attrs \\ %{}) do
    %GrantApprover{}
    |> GrantApprover.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Deletes a grant_approver.

  ## Examples

      iex> delete_grant_approver(grant_approver)
      {:ok, %GrantApprover{}}

      iex> delete_grant_approver(grant_approver)
      {:error, %Ecto.Changeset{}}

  """
  def delete_grant_approver(%GrantApprover{} = grant_approver) do
    Repo.delete(grant_approver)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking grant_approver changes.

  ## Examples

      iex> change_grant_approver(grant_approver)
      %Ecto.Changeset{data: %GrantApprover{}}

  """
  def change_grant_approver(%GrantApprover{} = grant_approver, attrs \\ %{}) do
    GrantApprover.changeset(grant_approver, attrs)
  end
end
