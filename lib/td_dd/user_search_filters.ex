defmodule TdDd.UserSearchFilters do
  @moduledoc """
  The UserSearchFilters context.
  """

  import Ecto.Query

  alias TdCache.Permissions
  alias TdDd.Repo
  alias TdDd.UserSearchFilters.UserSearchFilter

  defdelegate authorize(action, user, params), to: __MODULE__.Policy

  @doc """
  Returns the list of user_search_filters.

  ## Examples

      iex> list_user_search_filters()
      [%UserSearchFilter{}, ...]

  """
  def list_user_search_filters(params \\ %{}) do
    params
    |> user_search_filters_query()
    |> Repo.all()
  end

  @doc """
  Returns the list of user_search_filters for a given scope and user id.

  ## Examples

      iex> list_user_search_filters(%{"scope" => "rule"}, %Claims{user_id: 123})
      [%UserSearchFilter{}, ...]

  """
  def list_user_search_filters(%{} = params, %{user_id: user_id} = claims) do
    params
    |> Map.delete("user_id")
    |> user_search_filters_query()
    |> where([usf], usf.is_global or usf.user_id == ^user_id)
    |> Repo.all()
    |> maybe_filter(Map.get(params, "scope"), claims)
  end

  defp user_search_filters_query(params) do
    params
    |> Map.take(["user_id", "scope"])
    |> Enum.reduce(UserSearchFilter, fn
      {"user_id", user_id}, q -> where(q, user_id: type(^user_id, :integer))
      {"scope", scope}, q -> where(q, scope: ^scope)
    end)
  end

  defp maybe_filter(results, _scope, %{role: "admin"}), do: results

  defp maybe_filter(results, scope, claims) do
    case permitted_domain_ids(scope, claims) do
      [] ->
        if is_default_permission(scope), do: results, else: []

      domain_ids ->
        Enum.reject(results, fn
          %{filters: %{"taxonomy" => taxonomy}} ->
            MapSet.disjoint?(MapSet.new(taxonomy), MapSet.new(domain_ids))

          _ ->
            false
        end)
    end
  end

  defp permitted_domain_ids("data_structure", %{jti: jti}),
    do: Permissions.permitted_domain_ids(jti, "view_data_structure")

  defp permitted_domain_ids("rule", %{jti: jti}),
    do: Permissions.permitted_domain_ids(jti, "view_quality_rule")

  defp permitted_domain_ids("rule_implementation", %{jti: jti}),
    do: Permissions.permitted_domain_ids(jti, "view_quality_rule")

  defp permitted_domain_ids(_scope, _claims), do: []

  defp is_default_permission("data_structure"),
    do: Permissions.is_default_permission?("view_data_structure")

  defp is_default_permission("rule"),
    do: Permissions.is_default_permission?("view_quality_rule")

  defp is_default_permission("rule_implementation"),
    do: Permissions.is_default_permission?("view_quality_rule")

  defp is_default_permission(_scope), do: false

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
end
