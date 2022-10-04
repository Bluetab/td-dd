defmodule TdDdWeb.UnitController do
  use TdDdWeb, :controller
  use PhoenixSwagger

  alias TdDd.Lineage.Import
  alias TdDd.Lineage.Units

  action_fallback(TdDdWeb.FallbackController)

  def swagger_definitions do
    TdDdWeb.SwaggerDefinitions.unit_swagger_definitions()
  end

  swagger_path :index do
    description("List of Units")
    response(200, "OK", Schema.ref(:UnitsResponse))
  end

  def index(conn, _params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(Units, :list, claims),
         units <- Units.list_units(status: true) do
      render(conn, "index.json", units: units)
    end
  end

  swagger_path :show do
    description("Show Unit")
    response(200, "OK", Schema.ref(:UnitResponse))
    response(400, "Client Error")
  end

  def show(conn, %{"name" => name}) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(Units, :view, claims),
         {:ok, %Units.Unit{} = unit} <- Units.get_by(name: name, status: true) do
      render(conn, "show.json", unit: unit)
    end
  end

  swagger_path :create do
    description("Create Unit")
    response(200, "OK", Schema.ref(:UnitResponse))
    response(400, "Client Error")
  end

  def create(conn, %{} = params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(Units, :create, claims),
         {:ok, unit} <- Units.create_unit(params) do
      render(conn, "show.json", unit: unit)
    end
  end

  swagger_path :update do
    description("Replace Unit")
    response(202, "Accepted")
    response(400, "Client Error")
  end

  def update(conn, %{"nodes" => nodes, "rels" => rels} = params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(Units, :update, claims),
         {:ok, nodes_path} <- copy(nodes),
         {:ok, rels_path} <- copy(rels) do
      Import.load(nodes_path, rels_path, params)
      send_resp(conn, :accepted, "")
    end
  end

  swagger_path :delete do
    description("Delete Unit")
    response(202, "Accepted")
    response(400, "Client Error")
  end

  def delete(conn, %{"name" => name} = params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(Units, :delete, claims),
         {:ok, unit} <- Units.get_by(name: name),
         {:ok, _} <- Units.delete_unit(unit, logical: params["logical"] != "false") do
      send_resp(conn, :no_content, "")
    end
  end

  defp copy(%Plug.Upload{path: path, filename: filename}) do
    with dest_dir <- import_dir(),
         ts <- DateTime.utc_now() |> DateTime.to_unix(:millisecond),
         dest <- Path.join(dest_dir, "#{ts}-#{filename}"),
         {:cp, :ok} <- {:cp, File.cp(path, dest)} do
      {:ok, dest}
    end
  end

  defp import_dir do
    case Application.get_env(:td_dd, :import_dir) do
      nil -> System.tmp_dir!()
      dir -> dir
    end
  end
end
