defmodule TdDd.Canada.ExecutionAbilities do
  @moduledoc """
  Permissions for executions and execution groups.
  """

  alias TdDd.Executions.ProfileExecution
  alias TdDd.Executions.ProfileGroup

  import TdDd.Permissions, only: [authorized?: 2, authorized?: 3]

  def can?(%{role: "admin"}, _action, _target), do: true

  # Service accounts can do anything with executions and execution groups
  def can?(%{role: "service"}, _action, _target), do: true

  def can?(%{} = claims, :list, ProfileExecution),
    do: authorized?(claims, :view_data_structures_profile)

  def can?(%{} = claims, :list, ProfileGroup),
    do: authorized?(claims, :view_data_structures_profile)

  def can?(%{} = claims, :show, ProfileGroup),
    do: authorized?(claims, :view_data_structures_profile)

  def can?(%{} = claims, :create, ProfileGroup), do: authorized?(claims, :profile_structures)

  def can?(%{} = claims, :show, %ProfileExecution{data_structure: data_structure}) do
    Bodyguard.permit?(TdDd.DataStructures, :view_data_structure, claims, data_structure) &&
      view_profile?(claims, data_structure)
  end

  def can?(%{}, _action, _target), do: false

  defp view_profile?(%{} = claims, %{domain_ids: domain_ids}),
    do: authorized?(claims, :view_data_structures_profile, domain_ids)

  defp view_profile?(%{}, _data_structure), do: false
end
