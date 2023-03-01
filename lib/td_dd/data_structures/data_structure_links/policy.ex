defmodule TdDd.DataStructures.DataStructureLinks.Policy do
  @moduledoc "Authorization rules for TdDd.DataStructures.DataStructureLinks"

  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureLink
  alias TdDd.Permissions

  def authorize(_action, %{role: role}, _params) when role in ["admin", "service"], do: true

  def authorize(
        action,
        claims,
        {
          %DataStructure{domain_ids: source_domain_ids},
          %DataStructure{domain_ids: target_domain_ids}
        }
      ) when action in [:create, :delete] do
    source_and_target_permissions?({source_domain_ids, target_domain_ids}, claims)
  end

  def authorize(
        action,
        claims,
        %DataStructureLink{
          source: %DataStructure{domain_ids: source_structure_domain_ids},
          target: %DataStructure{domain_ids: target_structure_domain_ids}
        }
      ) when action in [:create, :delete] do
    source_and_target_permissions?(
      {source_structure_domain_ids, target_structure_domain_ids},
      claims
    )
  end

  def authorize(_action, _claims, _params), do: false

  defp source_and_target_permissions?(
         {source_structure_domain_ids, target_structure_domain_ids},
         claims
       ) do
    Permissions.authorized?(claims, :link_structure_to_structure, source_structure_domain_ids) and
    Permissions.authorized?(claims, :link_structure_to_structure, target_structure_domain_ids)
  end
end
