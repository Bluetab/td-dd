defmodule TdDdWeb.DataStructureView do
  use TdDdWeb, :view
  alias TdDdWeb.DataStructureView
  alias TdDd.Accounts.User
  alias TdDd.Utils.CollectionUtils
  alias Ecto

  def render("index.json", %{data_structures: data_structures, users: users}) do
    %{data: render_many(data_structures, DataStructureView, "data_structure.json", %{users: users})}
  end

  def render("show.json", %{data_structure: data_structure, users: users}) do
    %{data: render_one(data_structure, DataStructureView, "data_structure.json", %{users: users})}
  end

  def render("data_structure.json", %{data_structure: data_structure, users: users}) do
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
      inserted_at: data_structure.inserted_at,
      metadata: data_structure.metadata}
      |> add_data_fields(data_structure, users)
  end

  defp add_data_fields(data_structure_json, data_stucture, users) do
    data_fields = case Ecto.assoc_loaded?(data_stucture.data_fields) do
      true ->
        Enum.reduce(data_stucture.data_fields, [], fn(data_field, acc) ->
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
                   metadata: data_field.metadata}
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
