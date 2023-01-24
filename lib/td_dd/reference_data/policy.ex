defmodule TdDd.ReferenceData.Policy do
  @moduledoc "Authorization rules for reference data"

  alias TdCache.Permissions, as: CachePermissions
  alias TdDq.Permissions

  @behaviour Bodyguard.Policy

  def authorize(action, %{role: "user"} = claims, %{domain_ids: domain_ids})
      when action in [:show, :download] do
    Permissions.authorized?(claims, :view_data_structure, domain_ids)
  end

  def authorize(action, %{role: "user"} = claims, _params)
      when action in [:list, :view, :query, :download] do
    Permissions.authorized?(claims, :view_data_structure)
  end

  def authorize(action, %{role: "service"}, _params) when action in [:list, :show, :view, :query],
    do: true

  def authorize(_action, %{role: "admin"}, _params), do: true

  def authorize(_action, _claims, _params), do: false

  def view_permitted_domain_ids(%{role: role}) when role in ["admin", "service"], do: :all

  def view_permitted_domain_ids(%{jti: jti}) do
    CachePermissions.permitted_domain_ids(jti, "view_data_structure")
  end
end
