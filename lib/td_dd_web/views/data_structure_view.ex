defmodule TdDdWeb.DataStructureView do
  use TdDdWeb, :view
  alias Ecto
  alias TdDd.Accounts.User
  alias TdDdWeb.DataStructureView

  def render("index.json", %{data_structures: data_structures}) do
    %{data: render_many(data_structures, DataStructureView, "data_structure.json")}
  end

  def render("show.json", %{data_structure: data_structure, users: users}) do
    %{data:
      %{id: data_structure.id,
        system: data_structure.system,
        group: data_structure.group,
        name: data_structure.name,
        description: data_structure.description,
        type: data_structure.type,
        ou: data_structure.ou,
        lopd: data_structure.lopd,
        last_change_at: data_structure.last_change_at,
        last_change_by: get_last_change_by_user_name(data_structure.last_change_by, users),
        inserted_at: data_structure.inserted_at}
        |> add_data_fields(data_structure, users)
    }
  end

  def render("data_structure.json", %{data_structure: data_structure}) do
    %{id: data_structure.id,
      system: data_structure.system,
      group: data_structure.group,
      name: data_structure.name,
      description: data_structure.description,
      type: data_structure.type,
      ou: data_structure.ou,
      lopd: data_structure.lopd,
      last_change_at: data_structure.last_change_at,
      last_change_by: data_structure.last_change_by.user_name,
      inserted_at: data_structure.inserted_at}
      |> add_data_fields(data_structure)
  end

  defp add_data_fields(data_structure_json, data_structure) do
    data_fields =
      case Ecto.assoc_loaded?(data_structure.data_fields) do
        true ->
          Enum.reduce(data_structure.data_fields, [], fn(data_field, acc) ->
            json = %{id: data_field.id,
                     name: data_field.name,
                     type: data_field.type,
                     precision: data_field.precision,
                     nullable: data_field.nullable,
                     description: data_field.description,
                     business_concept_id: data_field.business_concept_id,
                     last_change_at: data_field.last_change_at,
                     inserted_at: data_field.inserted_at,
                     external_id: data_field.external_id,
                     bc_related: data_field.bc_related}
            [json|acc]
          end)
        _ -> []
    end
    Map.put(data_structure_json, :data_fields, data_fields)
  end

  defp add_data_fields(data_structure_json, data_structure, users) do
    data_fields =
      case Ecto.assoc_loaded?(data_structure.data_fields) do
        true ->
          Enum.reduce(data_structure.data_fields, [], fn(data_field, acc) ->
            json = %{id: data_field.id,
                     name: data_field.name,
                     type: data_field.type,
                     precision: data_field.precision,
                     nullable: data_field.nullable,
                     description: data_field.description,
                     business_concept_id: data_field.business_concept_id,
                     last_change_at: data_field.last_change_at,
                     last_change_by: get_last_change_by_user_name(data_field.last_change_by, users),
                     inserted_at: data_field.inserted_at,
                     external_id: data_field.external_id,
                     bc_related: data_field.bc_related}
            [json|acc]
          end)
        _ -> []
    end
    Map.put(data_structure_json, :data_fields, data_fields)
  end

  defp get_last_change_by_user_name(last_change_by_id, users) do
    default_username = Integer.to_string(last_change_by_id)
    default_user = %User{user_name: default_username}
    Enum.find(users, default_user, &(&1.id == last_change_by_id)).user_name
  end
end
