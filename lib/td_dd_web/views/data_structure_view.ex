defmodule TdDdWeb.DataStructureView do
  use TdDdWeb, :view
  alias Ecto
  alias TdDdWeb.DataStructureView

  def render("index.json", %{data_structures: data_structures}) do
    %{data: render_many(data_structures, DataStructureView, "data_structure.json")}
  end

  def render("show.json", %{
    data_structure: data_structure,
    user_permissions: user_permissions
  }) do
    %{
      user_permissions: user_permissions,
      data:
      %{
        id: data_structure.id,
        system: data_structure.system,
        group: data_structure.group,
        name: data_structure.name,
        description: data_structure.description,
        type: data_structure.type,
        ou: data_structure.ou,
        domain_id: data_structure.domain_id,
        last_change_at: data_structure.last_change_at,
        inserted_at: data_structure.inserted_at,
        df_name: data_structure.df_name,
        df_content: data_structure.df_content
      }
      |> add_data_fields(data_structure)
    }
  end

  def render("show.json", %{data_structure: data_structure}) do
    %{data:
      %{
        id: data_structure.id,
        system: data_structure.system,
        group: data_structure.group,
        name: data_structure.name,
        description: data_structure.description,
        type: data_structure.type,
        ou: data_structure.ou,
        domain_id: data_structure.domain_id,
        last_change_at: data_structure.last_change_at,
        inserted_at: data_structure.inserted_at,
        df_name: data_structure.df_name,
        df_content: data_structure.df_content
      }
      |> add_data_fields(data_structure)
    }
  end

  def render("data_structure.json", %{data_structure: data_structure}) do
    %{
      id: data_structure.id,
      system: data_structure.system,
      group: data_structure.group,
      name: data_structure.name,
      description: data_structure.description,
      type: data_structure.type,
      ou: data_structure.ou,
      domain_id: data_structure.domain_id,
      last_change_at: data_structure.last_change_at,
      inserted_at: data_structure.inserted_at,
      df_name: data_structure.df_name,
      df_content: data_structure.df_content
    }
    |> add_data_fields(data_structure)
  end

  defp add_data_fields(data_structure_json, data_structure) do
    data_fields =
      case Map.get(data_structure, :data_fields) do
        nil -> []
        fields ->
          Enum.reduce(fields, [], fn(data_field, acc) ->
            json = %{id: data_field.id,
                     name: data_field.name,
                     type: data_field.type,
                     precision: data_field.precision,
                     nullable: data_field.nullable,
                     description: data_field.description,
                     business_concept_id: data_field.business_concept_id,
                     last_change_at: data_field.last_change_at,
                     inserted_at: data_field.inserted_at,
                     external_id: Map.get(data_field, :external_id, nil),
                     bc_related: data_field.bc_related}
            [json|acc]
          end)
    end
    Map.put(data_structure_json, :data_fields, data_fields)
  end
end
