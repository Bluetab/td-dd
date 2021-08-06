defmodule TdDdWeb.UnitController do
  use TdDdWeb, :controller
  use PhoenixSwagger

  import Canada, only: [can?: 2]

  alias TdCache.TaxonomyCache
  alias TdDd.Lineage.Import
  alias TdDd.Lineage.Units
  alias TdDd.Lineage.Units.Unit

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

    with {:can, true} <- {:can, can?(claims, list(Unit))},
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

    with {:can, true} <- {:can, can?(claims, show(Unit))},
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
    attrs = attributes(params)

    with {:can, true} <- {:can, can?(claims, create(Unit))},
         {:ok, unit} <- Units.create_unit(attrs) do
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
    attrs = attributes(params)

    with {:can, true} <- {:can, can?(claims, update(Unit))},
         {:ok, nodes_path} <- copy(nodes),
         {:ok, rels_path} <- copy(rels) do
      Import.load(nodes_path, rels_path, attrs)
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

    with {:can, true} <- {:can, can?(claims, delete(Unit))},
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

  defp attributes(params) do
    Map.new()
    |> with_name(params)
    |> with_domain_id(params)
  end

  defp with_name(acc, %{"name" => name}), do: Map.put(acc, :name, name)
  defp with_name(acc, _attrs), do: acc

  defp with_domain_id(acc, %{"domain" => domain}) do
    domain_id = Map.get(TaxonomyCache.get_domain_external_id_to_id_map(), domain)
    Map.put(acc, :domain_id, domain_id)
  end

  defp with_domain_id(acc, _attrs), do: acc
end
