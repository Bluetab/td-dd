defmodule TdDd.DataStructures.DataStructureLinks.Policy do
  @moduledoc "Authorization rules for TdDd.DataStructures.DataStructureLinks"

  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureLink
  alias TdDd.Permissions

  def authorize(_action, %{role: role}, _params) when role in ["admin", "service"], do: true

  ## REVIEW TD-5509: No debería de revisarse los actions????
  ## por que se verifica una vez el target y el source con el autorize???
  ## Y no en el controlador
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
    |> List.to_tuple()
    |> source_and_target_permissions?(claims)
  end

  def authorize(
        _action,
        claims,
        %DataStructureLink{
          source: %DataStructure{domain_ids: source_structure_domain_ids},
          target: %DataStructure{domain_ids: target_structure_domain_ids}
        }
      ) do
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
    any_domain_id_authorized?(source_structure_domain_ids, claims) and
      any_domain_id_authorized?(target_structure_domain_ids, claims)
  end

  ## REVIEW TD-5509: Creo recordar que ya existe una funcionalidad que revisa si hay alguno de los permisos
  ## directamente en  Permissions
  defp any_domain_id_authorized?(structure_domain_ids, claims) do
    structure_domain_ids
    |> Enum.map(&Permissions.authorized?(claims, :link_structure_to_structure, &1))
    |> Enum.any?()
  end
end
