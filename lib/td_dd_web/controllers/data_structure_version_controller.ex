defmodule TdDdWeb.DataStructureVersionController do
  use TdDdWeb, :controller
  use PhoenixSwagger

  alias TdDd.DataStructures.DataStructureVersions
  alias TdDdWeb.SwaggerDefinitions

  action_fallback(TdDdWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.data_structure_version_swagger_definitions()
  end

  swagger_path :show do
    description("Show Data Structure")
    produces("application/json")

    parameters do
      id(:path, :integer, "Data Structure ID", required: true)
      version(:path, :integer, "Version number", required: true)
    end

    response(200, "OK", Schema.ref(:DataStructureVersionResponse))
    response(400, "Client Error")
    response(403, "Forbidden")
    response(422, "Unprocessable Entity")
  end

  def show(conn, %{"data_structure_id" => data_structure_id, "id" => version}) do
    conn.assigns[:current_resource]
    |> DataStructureVersions.enriched_data_structure_version(data_structure_id, version)
    |> render_data_structure_version(conn)
  end

  def show(conn, %{"id" => data_structure_version_id}) do
    conn.assigns[:current_resource]
    |> DataStructureVersions.enriched_data_structure_version(data_structure_version_id)
    |> render_data_structure_version(conn)
  end

  defp render_data_structure_version([_ | _] = args, conn), do: render(conn, "show.json", args)
  defp render_data_structure_version(error, conn), do: render_error(conn, error)
end
