defmodule TdDdWeb.DataStructureVersionController do
  use TdDdWeb, :controller

  alias TdDd.DataStructures.DataStructureVersions

  action_fallback(TdDdWeb.FallbackController)

  def show(conn, %{"data_structure_id" => data_structure_id, "id" => version}) do
    conn.assigns[:current_resource]
    |> DataStructureVersions.enriched_data_structure_version(data_structure_id, version)
    |> render_data_structure_version(conn)
  end

  def show(conn, %{"id" => data_structure_version_id}) do
    conn.assigns[:current_resource]
    |> DataStructureVersions.enriched_data_structure_version_by_id(data_structure_version_id)
    |> render_data_structure_version(conn)
  end

  defp render_data_structure_version([_ | _] = args, conn), do: render(conn, "show.json", args)
  defp render_data_structure_version(error, conn), do: render_error(conn, error)
end
