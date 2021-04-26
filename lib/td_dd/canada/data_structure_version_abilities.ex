defmodule TdDd.Canada.DataStructureVersionAbilities do
  @moduledoc false
  alias TdDd.Auth.Claims
  alias TdDd.Canada.DataStructureAbilities
  alias TdDd.Permissions

  # Only field structures or structures containing fields can be profiled
  def can?(%Claims{} = claims, :profile, %{
        class: class,
        data_fields: fields,
        source: %{config: %{"job_types" => job_types}},
        data_structure: data_structure
      }) when fields != [] or class == "field" do
    Enum.member?(job_types, "profile") && can_profile(claims, data_structure)
  end

  def can?(%Claims{}, :profile, _resource), do: false

  def can?(%Claims{} = claims, action, %{data_structure: data_structure}) do
    DataStructureAbilities.can?(claims, action, data_structure)
  end

  def can?(%Claims{}, _action, _resource), do: false

  defp can_profile(%Claims{role: "admin"}, _), do: true
  defp can_profile(%Claims{} = claims, %{domain_id: domain_id} = _data_structure) do
    Permissions.authorized?(claims, :profile_structures, domain_id)
  end
end
