defmodule TdDd.Canada.DataStructureVersionAbilities do
  @moduledoc false
  alias TdDd.Auth.Claims
  alias TdDd.Canada.DataStructureAbilities
  alias TdDd.Permissions

  def can?(%Claims{role: "admin"}, :profile_structures, %{
        class: "field",
        source: %{config: %{"job_types" => job_types}}
      }) do
    Enum.member?(job_types, "profile")
  end

  def can?(%Claims{} = claims, :profile_structures, %{
        class: "field",
        source: %{config: %{"job_types" => job_types}},
        data_structure: %{domain_id: domain_id}
      }) do
    Enum.member?(job_types, "profile") &&
      Permissions.authorized?(claims, :profile_structures, domain_id)
  end

  # Only field structures can be manually profiled
  def can?(%Claims{}, :profile_structures, _resource), do: false

  def can?(%Claims{} = claims, action, %{data_structure: data_structure}) do
    DataStructureAbilities.can?(claims, action, data_structure)
  end

  def can?(%Claims{}, _action, _resource), do: false
end
