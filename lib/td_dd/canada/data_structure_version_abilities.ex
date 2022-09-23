defmodule TdDd.Canada.DataStructureVersionAbilities do
  @moduledoc false
  alias TdDd.Canada.DataStructureAbilities
  alias TdDd.Permissions

  # Only field structures or structures containing fields can be profiled
  def can?(%{role: "admin"}, :profile, dsv), do: profilable?(dsv)

  def can?(%{} = claims, :profile, %{data_structure: %{domain_ids: domain_ids}} = dsv) do
    profilable?(dsv) and
      Permissions.authorized?(claims, :profile_structures, domain_ids)
  end

  def can?(%{}, :profile, _resource), do: false

  def can?(%{} = claims, action, %{data_structure: data_structure}) do
    DataStructureAbilities.can?(claims, action, data_structure)
  end

  def can?(%{}, _action, _resource), do: false

  defp profilable?(%{class: "field"}), do: true
  defp profilable?(%{data_fields: [_ | _]}), do: true
  defp profilable?(_), do: false
end
