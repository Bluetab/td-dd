defmodule TdDd.Profiles.Policy do
  @moduledoc "Authorization rules for profiles"

  alias TdDd.Permissions

  @behaviour Bodyguard.Policy

  def authorize(:profile, %{role: "admin"}, dsv), do: profilable?(dsv)

  def authorize(:profile, %{} = claims, %{data_structure: %{domain_ids: domain_ids}} = dsv) do
    profilable?(dsv) and
      Permissions.authorized?(claims, :profile_structures, domain_ids)
  end

  def authorize(_action, %{role: "service"}, _params), do: true
  def authorize(_action, %{role: "admin"}, _params), do: true

  def authorize(:search, %{} = claims, _params) do
    Permissions.authorized?(claims, :view_data_structures_profile)
  end

  def authorize(:view, %{} = claims, %{data_structure: %{domain_ids: domain_ids} = ds})
      when is_list(domain_ids) do
    Bodyguard.permit?(TdDd.DataStructures, :view_data_structure, claims, ds) and
      Permissions.authorized?(claims, :view_data_structures_profile, domain_ids)
  end

  def authorize(:create, %{} = claims, _params) do
    Permissions.authorized?(claims, :profile_structures)
  end

  def authorize(_action, _claims, _params), do: false

  defp profilable?(%{class: "field"}), do: true
  defp profilable?(%{data_fields: [_ | _]}), do: true
  defp profilable?(%{data_fields: {_version = [_ | _], _meta}}), do: true
  defp profilable?(_), do: false
end
