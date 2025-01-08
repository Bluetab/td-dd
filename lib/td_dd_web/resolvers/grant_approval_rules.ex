defmodule TdDdWeb.Resolvers.GrantApprovalRules do
  @moduledoc """
  Absinthe resolvers for grant approval rules
  """

  alias TdDd.Grants.ApprovalRules

  def grant_approval_rules(_parent, _args, resolution) do
    %{user_id: user_id} = claims(resolution)
    {:ok, ApprovalRules.list_by_user(user_id)}
  end

  def grant_approval_rule(_parent, %{id: id}, resolution) do
    with {:claims, %{} = claims} <- {:claims, claims(resolution)},
         grant_approval_rule <- ApprovalRules.get!(id),
         :ok <- Bodyguard.permit(ApprovalRules, :view, claims, grant_approval_rule) do
      {:ok, grant_approval_rule}
    else
      {:claims, nil} -> {:error, :unauthorized}
      {:error, :forbidden} -> {:error, :forbidden}
    end
  rescue
    _ -> {:error, :not_found}
  end

  def create_grant_approval_rule(_parent, %{approval_rule: params}, resolution) do
    with {:claims, %{} = claims} <- {:claims, claims(resolution)},
         domain_ids <- Map.get(params, :domain_ids),
         :ok <- Bodyguard.permit(ApprovalRules, :create_approval_rule, claims, domain_ids),
         {:ok, %{id: id}} <- ApprovalRules.create(params, claims) do
      {:ok, ApprovalRules.get!(id)}
    else
      {:claims, nil} -> {:error, :unauthorized}
      {:error, error} -> {:error, error}
      {:error, _, changeset, _} -> {:error, changeset}
    end
  end

  def update_grant_approval_rule(_parent, %{approval_rule: params}, resolution) do
    with {:claims, %{} = claims} <- {:claims, claims(resolution)},
         approval_rule_id <- Map.get(params, :id),
         approval_rule <- ApprovalRules.get!(approval_rule_id),
         :ok <- Bodyguard.permit(ApprovalRules, :update_approval_rule, claims, approval_rule),
         {:ok, %{id: id}} <- ApprovalRules.update(approval_rule, params, claims) do
      {:ok, ApprovalRules.get!(id)}
    else
      {:claims, nil} -> {:error, :unauthorized}
      {:error, error} -> {:error, error}
      {:error, _, changeset, _} -> {:error, changeset}
    end
  end

  def delete_grant_approval_rule(_parent, %{id: id}, resolution) do
    with {:claims, %{} = claims} <- {:claims, claims(resolution)},
         approval_rule <- ApprovalRules.get!(id),
         :ok <- Bodyguard.permit(ApprovalRules, :delete_approval_rule, claims, approval_rule) do
      ApprovalRules.delete(approval_rule)
    else
      {:claims, nil} -> {:error, :unauthorized}
      {:error, error} -> {:error, error}
    end
  end

  defp claims(%{context: %{claims: claims}}), do: claims
  defp claims(_), do: nil
end
