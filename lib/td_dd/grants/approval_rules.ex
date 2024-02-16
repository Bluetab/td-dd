defmodule TdDd.Grants.ApprovalRules do
  @moduledoc """
  Approval Rules context
  """

  import Ecto.Query

  alias TdCache.TaxonomyCache
  alias TdDd.Grants.ApprovalRule
  alias TdDd.Grants.GrantRequest
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

  def get_rules_for_request(
        %GrantRequest{domain_ids: request_domain_ids, all_pending_roles: pending_roles} =
          grant_request
      ) do
    domain_ids = TaxonomyCache.reaching_domain_ids(request_domain_ids)

    rules =
      ApprovalRule
      |> where([ar], fragment("? && ?", ar.domain_ids, ^domain_ids))
      |> Repo.all()
      |> Enum.filter(
        &(&1.role in pending_roles and
            match_conditions(&1, grant_request))
      )
      |> Enum.group_by(& &1.action)
      |> maybe_get_reject_rules()
      |> Enum.uniq_by(& &1.role)

    {grant_request, rules}
  end

  defp maybe_get_reject_rules(%{"reject" => [_ | _] = rules}), do: rules
  defp maybe_get_reject_rules(%{"approve" => [_ | _] = rules}), do: rules
  defp maybe_get_reject_rules(_), do: []

  defp match_conditions(%{conditions: conditions}, grant_request) do
    Enum.all?(conditions, &match_condition(&1, grant_request))
  end

  defp match_condition(%{value: value, values: nil} = condition, grant_request)
       when is_binary(value) do
    # TD-5391 value is deprecated - use values instead
    match_condition(%{condition | values: [value], value: nil}, grant_request)
  end

  defp match_condition(
         %{field: "request." <> field, operator: operator, values: values},
         grant_request
       ) do
    metadata = get_request_metadata(grant_request)
    match_condition(field, operator, values, metadata)
  end

  defp match_condition(
         %{field: "metadata." <> field, operator: operator, values: values},
         grant_request
       ) do
    metadata = get_data_structure_metadata(grant_request)
    mutable = get_data_structure_mutable_metadata(grant_request)

    match_condition(field, operator, values, metadata) or
      match_condition(field, operator, values, mutable)
  end

  defp match_condition(
         %{field: "note." <> field, operator: operator, values: values},
         grant_request
       ) do
    metadata = get_data_structure_note(grant_request)
    match_condition(field, operator, values, metadata)
  end

  defp match_condition(_, _), do: false

  defp match_condition(_, _, _, nil), do: false

  defp match_condition(field, "eq", [value], metadata) when is_map_key(metadata, field),
    do: value == Map.get(metadata, field)

  defp match_condition(field, "neq", [value], metadata) when is_map_key(metadata, field),
    do: value != Map.get(metadata, field)

  defp match_condition(field, "subset", values, metadata)
       when is_map_key(metadata, field) and is_list(values) do
    metadata
    |> Map.get(field)
    |> List.wrap()
    |> MapSet.new()
    |> MapSet.subset?(MapSet.new(values))
  end

  defp match_condition(_, _, _, _), do: false

  defp get_request_metadata(%{metadata: metadata}), do: metadata
  defp get_request_metadata(_), do: nil

  defp get_data_structure_note(%{
         data_structure: %{
           current_version: %{data_structure: %{published_note: %{df_content: metadata}}}
         }
       }),
       do: metadata

  defp get_data_structure_note(_), do: nil

  defp get_data_structure_metadata(%{data_structure: %{current_version: %{metadata: metadata}}}),
    do: metadata

  defp get_data_structure_metadata(_), do: nil

  defp get_data_structure_mutable_metadata(%{
         data_structure: %{current_version: %{current_metadata: %{fields: metadata}}}
       }),
       do: metadata

  defp get_data_structure_mutable_metadata(_), do: nil
end
