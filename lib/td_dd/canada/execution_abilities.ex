defmodule TdDd.Canada.ExecutionAbilities do
  @moduledoc """
  Permissions for executions and execution groups.
  """

  alias TdDd.Auth.Claims
  alias TdDd.Executions.Execution
  alias TdDd.Executions.Group

  import TdDd.Permissions, only: [authorized?: 2, authorized?: 3]

  def can?(%Claims{role: "admin"}, _action, _target), do: true

  # Service accounts can do anything with executions and execution groups
  def can?(%Claims{role: "service"}, _action, _target), do: true

  def can?(%Claims{} = claims, :list, Execution),
    do: authorized?(claims, :view_data_structures_profile)

  def can?(%Claims{} = claims, :list, Group),
    do: authorized?(claims, :view_data_structures_profile)

  def can?(%Claims{} = claims, :show, Group),
    do: authorized?(claims, :view_data_structures_profile)

  def can?(%Claims{} = claims, :create, Group),
    do: authorized?(claims, :profile_structures)

  def can?(%Claims{} = claims, :show, %Execution{data_structure: data_structure}),
    do: view_structure?(claims, data_structure) && view_profile?(claims, data_structure)

  def can?(%Claims{}, _action, _target), do: false

  defp view_structure?(%Claims{} = claims, %{domain_id: domain_id, confidential: confidential}) do
    authorized?(claims, :view_data_structure, domain_id) &&
      (!confidential || authorized?(claims, :manage_confidential_structures, domain_id))
  end

  defp view_structure?(%Claims{}, _data_structure), do: false

  defp view_profile?(%Claims{} = claims, %{domain_id: domain_id}),
    do: authorized?(claims, :view_data_structures_profile, domain_id)

  defp view_profile?(%Claims{}, _data_structure), do: false
end
