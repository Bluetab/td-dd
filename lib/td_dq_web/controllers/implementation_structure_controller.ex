defmodule TdDqWeb.ImplementationStructureController do
  use TdDqWeb, :controller

  import Canada, only: [can?: 2]

  alias TdDd.DataStructures
  alias TdDq.Implementations
  alias TdDq.Implementations.ImplementationStructure

  action_fallback TdDqWeb.FallbackController

  def create(conn, %{
        "implementation_id" => implementation_id,
        "data_structure_id" => data_structure_id,
        "type" => type
      }) do
    claims = conn.assigns[:current_resource]

    with implementation = %{} <- Implementations.get_implementation(implementation_id),
         data_structure = %{} <- DataStructures.get_data_structure(data_structure_id),
         {:can, true} <- {:can, can?(claims, link_structure(implementation))},
         {:can, true} <- {:can, can?(claims, link_data_structure(data_structure))},
         {:ok, %ImplementationStructure{} = implementation_structure} <-
           Implementations.create_implementation_structure(
             implementation,
             data_structure,
             %{"type" => type}
           ) do
      conn
      |> put_status(:created)
      |> put_resp_header(
        "location",
        Routes.implementation_path(conn, :show, implementation_id)
      )
      |> render("show.json", implementation_structure: implementation_structure)
    end
  end

  def delete(
        conn,
        %{"id" => data_structure_id, "implementation_id" => implementation_id}
      ) do
    claims = conn.assigns[:current_resource]

    with %{implementation: implementation} = implementation_structure <-
           Implementations.get_implementation_structure!(
             implementation_id,
             data_structure_id,
             _preloads = :implementation
           ),
         {:can, true} <- {:can, can?(claims, link_structure(implementation))},
         {:ok, %ImplementationStructure{}} <-
           Implementations.delete_implementation_structure(implementation_structure) do
      send_resp(conn, :no_content, "")
    end
  end
end
