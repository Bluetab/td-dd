defmodule TdDd.UserSearchFilters do
  @moduledoc """
  The UserSearchFilters context.
  """

  import Ecto.Query
  alias TdDd.Repo

  alias TdDd.UserSearchFilters.UserSearchFilter

  @doc """
  Returns the list of user_search_filters.

  ## Examples

      iex> list_user_search_filters(%{"user_id" => 123})
      [%UserSearchFilter{}, ...]

  """
  def list_user_search_filters(criteria \\ []) do
    criteria
    |> Enum.reduce(UserSearchFilter, fn
        {"scope", scope_string}, query ->
          case UserSearchFilter.scope_to_atom(scope_string) do
            nil -> where(query, [usf], is_nil(usf.scope))
            scope -> where(query, [usf], usf.scope == ^scope)
          end
        {"user_id", user_id}, query -> where(query, [usf], usf.user_id == ^user_id)
        _, query -> query
      end
    )
    |> Repo.all()
  end

  @doc """
  Gets a single user_search_filter.

  Raises `Ecto.NoResultsError` if the User search filter does not exist.

  ## Examples

      iex> get_user_search_filter!(123)
      %UserSearchFilter{}

      iex> get_user_search_filter!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user_search_filter!(id), do: Repo.get!(UserSearchFilter, id)

  @doc """
  Creates a user_search_filter.

  ## Examples

      iex> create_user_search_filter(%{field: value})
      {:ok, %UserSearchFilter{}}

      iex> create_user_search_filter(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user_search_filter(attrs \\ %{}) do
    %UserSearchFilter{}
    |> UserSearchFilter.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user_search_filter.

  ## Examples

      iex> update_user_search_filter(user_search_filter, %{field: new_value})
      {:ok, %UserSearchFilter{}}

      iex> update_user_search_filter(user_search_filter, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_search_filter(%UserSearchFilter{} = user_search_filter, attrs) do
    user_search_filter
    |> UserSearchFilter.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user_search_filter.

  ## Examples

      iex> delete_user_search_filter(user_search_filter)
      {:ok, %UserSearchFilter{}}

      iex> delete_user_search_filter(user_search_filter)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user_search_filter(%UserSearchFilter{} = user_search_filter) do
    Repo.delete(user_search_filter)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user_search_filter changes.

  ## Examples

      iex> change_user_search_filter(user_search_filter)
      %Ecto.Changeset{data: %UserSearchFilter{}}

  """
  def change_user_search_filter(%UserSearchFilter{} = user_search_filter, attrs \\ %{}) do
    UserSearchFilter.changeset(user_search_filter, attrs)
  end
end
