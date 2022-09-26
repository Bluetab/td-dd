defmodule TdDd.Profiles.Policy do
  @moduledoc "Authorization rules for profiles"

  alias TdDd.Permissions

  @behaviour Bodyguard.Policy

  def authorize(:search, %{role: "user"} = claims, _params) do
    Permissions.authorized?(claims, :view_data_structures_profile)
  end

  def authorize(:view, %{role: "user"} = claims, %{data_structure: %{domain_ids: domain_ids} = ds})
      when is_list(domain_ids) do
    Bodyguard.permit?(TdDd.DataStructures, :view_data_structure, claims, ds) and
      Permissions.authorized?(claims, :view_data_structures_profile, domain_ids)
  end

  def authorize(:create, %{role: "user"} = claims, _params) do
    Permissions.authorized?(claims, :profile_structures)
  end

  def authorize(_action, %{role: "service"}, _params), do: true
  def authorize(_action, %{role: "admin"}, _params), do: true

  def authorize(_action, _claims, _params), do: false
end
