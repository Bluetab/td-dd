defmodule TdDd.DataStructures.DataStructureLinks.Policy do
  @moduledoc "Authorization rules for TdDd.DataStructures.DataStructureLinks"

  alias TdDd.Permissions

  def authorize(_action, %{role: role}, _params) when role in ["admin", "service"], do: true

  def authorize(
        _action,
        claims,
        %Ecto.Changeset{
          changes: %{
            source_id: source_id,
            target_id: target_id
          },
          valid?: true
        }
      ) do
    [source_id, target_id]
    |> TdDd.DataStructures.get_data_structures()
    |> Enum.map(& &1.domain_ids)
    |> source_and_target_permissions?(claims)
  end

  def authorize(_action, _claims, _params), do: false

  defp source_and_target_permissions?(
         [source_structure_domain_ids, target_structure_domain_ids],
         claims
       ) do
    any_domain_id_authorized?(source_structure_domain_ids, claims) and
      any_domain_id_authorized?(target_structure_domain_ids, claims)
  end

  defp any_domain_id_authorized?(structure_domain_ids, claims) do
    structure_domain_ids
    |> Enum.map(&Permissions.authorized?(claims, :link_structure_to_structure, &1))
    |> Enum.any?()
  end
end
