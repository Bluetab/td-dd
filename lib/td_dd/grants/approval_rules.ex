defmodule TdDd.Grants.ApprovalRules do
  @moduledoc """
  Approval Rules context
  """

  import Ecto.Query

  alias TdDd.Grants.ApprovalRule
  alias TdDd.Repo
  alias Truedat.Auth.Claims

  defdelegate authorize(action, user, params), to: TdDd.Grants.Policy

  @doc """
  Gets a single ApprovalRule.

  Raises `Ecto.NoResultsError` if the ApprovalRule does not exist.

  ## Examples

      iex> get!(123)
      %ApprovalRule{}

      iex> get!(456)
      ** (Ecto.NoResultsError)

  """
  def get!(id) do
    Repo.get!(ApprovalRule, id)
  end

  @doc """
  Returns the list of approval Rule by user_id.

  ## Examples

      iex> list_by_user(user_id)
      [%ApprovalRule{}, ...]

  """
  def list_by_user(user_id) do
    ApprovalRule
    |> where([ar], ar.user_id == ^user_id)
    |> order_by([ar], asc: ar.inserted_at)
    |> Repo.all()
  end

  @doc """
  Creates a approval Rule.

  ## Examples

      iex> create(%{field: value}, claims)
      {:ok, %ApprovalRule{}}

      iex> create(%{field: bad_value}, claims)
      {:error, %Ecto.Changeset{}}

  """
  def create(params, %Claims{user_id: user_id} = claims) do
    %ApprovalRule{user_id: user_id}
    |> ApprovalRule.changeset(params, claims)
    |> Repo.insert()
  end

  @doc """
  Updates a Approval Rules.

  ## Examples

      iex> update(approval_rule, %{field: new_value}, claims)
      {:ok, %ApprovalRule{}}

      iex> update(approval_rule, %{field: bad_value}, claims)
      {:error, %Ecto.Changeset{}}

  """

  def update(%ApprovalRule{} = approval_rule, params, claims) do
    approval_rule
    |> ApprovalRule.changeset(params, claims)
    |> Repo.update()
  end

  @doc """
    Delete a Approval Rules.

    ## Examples

        iex> delete(approval_rule)
        {:ok, %ApprovalRule{}}

        iex> update(approval_rule, %{field: bad_value})
        {:error, %Ecto.Changeset{}}
  """
  def delete(%ApprovalRule{} = approval_rule) do
    Repo.delete(approval_rule)
  end
end
