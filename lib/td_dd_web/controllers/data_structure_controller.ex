defmodule TdDdWeb.DataStructureController do
  use TdDdWeb, :controller
  use PhoenixSwagger

  import Bodyguard, only: [permit?: 4]
  import Canada, only: [can?: 2]
  import Canada.Can, only: [can?: 3]

  alias TdDd.CSV.Download
  alias TdDd.DataStructures
  alias TdDd.DataStructures.BulkUpdate
  alias TdDd.DataStructures.BulkUpdater
  alias TdDd.DataStructures.CsvBulkUpdateEvent
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.Search
  alias TdDd.DataStructures.StructureNotes
  alias TdDd.DataStructures.StructureNotesWorkflow
  alias TdDd.DataStructures.Tags
  alias TdDd.Utils.FileHash
  alias TdDdWeb.SwaggerDefinitions

  @lift_attrs [:class, :description, :metadata, :group, :name, :type, :deleted_at]
  @enrich_attrs [
    :children,
    :data_field_degree,
    :data_field_links,
    :data_fields,
    :domain,
    :source,
    :links,
    :parents,
    :relations,
    :siblings,
    :system,
    :versions,
    :with_protected_metadata,
    :metadata_versions,
    :data_structure_type
  ]

  @structures_actions [:update_domain_ids]

  plug(TdDdWeb.SearchPermissionPlug)

  action_fallback(TdDdWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.data_structure_swagger_definitions()
  end

  swagger_path :index do
    description("List Data Structures")
    response(200, "OK", Schema.ref(:DataStructuresResponse))
  end

  def index(conn, _params) do
    %{results: data_structures} = do_search(conn, %{}, 0, 10_000)
    render(conn, "index.json", data_structures: data_structures)
  end

  swagger_path :search do
    description("Data Structures")

    parameters do
      search(:body, Schema.ref(:DataStructureSearchRequest), "Search query parameter")
    end

    response(200, "OK", Schema.ref(:DataStructuresResponse))
  end

  def search(conn, params) do
    %{total: total} = response = do_search(conn, params)

    conn
    |> put_resp_header("x-total-count", "#{total}")
    |> put_actions(params, total)
    |> render("index.json", search_assigns(response))
  end

  swagger_path :update do
    description("Update Data Structures")
    produces("application/json")

    parameters do
      id(:path, :integer, "Data Structure ID", required: true)
      data_field(:body, Schema.ref(:DataStructureUpdate), "Data Structure update attrs")
    end

    response(201, "OK", Schema.ref(:DataStructureResponse))
    response(400, "Client Error")
    response(403, "Forbidden")
    response(422, "Unprocessable Entity")
  end

  def update(conn, %{"id" => id, "data_structure" => structure_params} = params) do
    inherit = Map.get(params, "inherit", false)
    claims = conn.assigns[:current_resource]
    structure = DataStructures.get_data_structure!(id)

    with %{valid?: true} = changeset <-
           DataStructures.update_changeset(claims, structure, structure_params),
         {:can, true} <- {:can, can?(claims, update_data_structure(changeset))},
         {:ok, _} <- DataStructures.update_data_structure(claims, changeset, inherit) do
      claims = conn.assigns[:current_resource]
      options = filter_opts(claims, structure)
      structure = get_data_structure(id, options)
      do_render_data_structure(conn, claims, structure)
    else
      %{valid?: false} = changeset -> {:error, changeset}
      other -> other
    end
  end

  defp filter_opts(claims, structure) do
    Enum.filter(@enrich_attrs, fn
      :with_protected_metadata -> can?(claims, view_protected_metadata(structure))
      _ -> true
    end)
  end

  swagger_path :delete do
    description("Delete Data Structure")
    produces("application/json")

    parameters do
      id(:path, :integer, "Data Structure ID", required: true)
      logical(:query, :boolean, "Logical delete flag")
    end

    response(204, "No Content")
    response(400, "Client Error")
    response(403, "Forbidden")
    response(422, "Unprocessable Entity")
  end

  def delete(conn, %{"id" => id, "logical" => "true"}) do
    claims = conn.assigns[:current_resource]

    with %DataStructure{} = data_structure <-
           DataStructures.get_data_structure!(id),
         {:can, true} <- {:can, can?(claims, delete_structure(data_structure))},
         %DataStructureVersion{} = data_structure_version <-
           DataStructures.get_latest_version(data_structure),
         {:ok, _} <-
           DataStructures.logical_delete_data_structure(
             data_structure_version,
             claims
           ) do
      send_resp(conn, :no_content, "")
    end
  end

  def delete(conn, %{"id" => id}) do
    claims = conn.assigns[:current_resource]
    data_structure = DataStructures.get_data_structure!(id)

    with {:can, true} <- {:can, can?(claims, delete_data_structure(data_structure))},
         {:ok, %{data_structure: _deleted_data_structure}} <-
           DataStructures.delete_data_structure(data_structure, claims) do
      send_resp(conn, :no_content, "")
    end
  end

  swagger_path :get_system_structures do
    description("List System Root Data Structures")

    parameters do
      system_id(:path, :string, "List of organizational units", required: true)
    end

    response(200, "OK", Schema.ref(:DataStructuresResponse))
  end

  def get_system_structures(conn, %{"system_id" => system_id} = params) do
    claims = conn.assigns[:current_resource]
    permission = conn.assigns[:search_permission]

    %{results: data_structures, total: total} =
      params
      |> Map.put("filters", %{"system_id" => String.to_integer(system_id)})
      |> Map.put("without", ["path", "deleted_at"])
      |> Search.search_data_structures(claims, permission, 0, 1_000)

    conn
    |> put_resp_header("x-total-count", "#{total}")
    |> render("index.json", data_structures: data_structures)
  end

  swagger_path :bulk_update do
    description("Bulk Update of extra info structures")
    produces("application/json")

    parameters do
      bulk_update_request(
        :body,
        Schema.ref(:BulkUpdateRequest),
        "Search query filter parameters and update attributes"
      )
    end

    response(200, "OK", Schema.ref(:BulkUpdateResponse))
    response(403, "User is not authorized to perform this action")
    response(422, "Error during bulk update")
  end

  def bulk_update(conn, %{
        "bulk_update_request" =>
          %{
            "search_params" => search_params,
            "update_attributes" => update_params
          } = bulk_update_request
      }) do
    claims = conn.assigns[:current_resource]
    permission = conn.assigns[:search_permission]
    auto_publish = bulk_update_request |> Map.get("auto_publish", false)

    with {:can, true} <- {:can, can?(claims, create(BulkUpdate))},
         %{results: results} <- search_all_structures(claims, permission, search_params),
         ids <- Enum.map(results, & &1.id),
         {:ok, %{update_notes: update_notes}} <-
           BulkUpdate.update_all(ids, update_params, claims, auto_publish),
         [updated_notes, not_updated_notes] <- BulkUpdate.split_succeeded_errors(update_notes),
         body <-
           Jason.encode!(%{
             ids: Enum.uniq(Map.keys(updated_notes)),
             errors:
               not_updated_notes
               |> Enum.map(fn {_id, {:error, {error, %{external_id: external_id} = _ds}}} ->
                 get_messsage_from_error(error)
                 |> Enum.map(fn ms ->
                   ms
                   |> Map.put(:external_id, external_id)
                 end)
               end)
               |> List.flatten()
           }) do
      conn
      |> put_resp_content_type("application/json", "utf-8")
      |> send_resp(:ok, body)
    end
  end

  swagger_path :bulk_upload_domains do
    description("structures domains bulk update by CSV upload")
    produces("application/json")
    consumes("multipart/form-data")

    parameter(
      :structures_domains,
      :formData,
      :file,
      "Structures domains CSV file (column headers: external_id, domain_external_ids)"
    )

    response(200, "OK", Schema.ref(:BulkUploadDomainsResponse))
    response(403, "User is not authorized to perform this action")
    response(422, "Invalid CSV format (bad headers...)")
  end

  def bulk_upload_domains(conn, params) do
    structures_content_upload = Map.get(params, "structures_domains")
    headers = ["external_id", "domain_external_ids"]

    with claims <- conn.assigns[:current_resource],
         {:can, true} <- {:can, can?(claims, update_domain_ids(DataStructure))},
         :ok <-
           BulkUpdate.check_csv_headers(structures_content_upload, headers),
         [_ | _] = rows <- BulkUpdate.from_csv(structures_content_upload, :simple),
         info <- BulkUpdate.csv_bulk_update_domains(rows, claims),
         summary <- csv_bulk_upload_domains_summary(rows, info) do
      conn
      |> put_resp_content_type("application/json", "utf-8")
      |> send_resp(:ok, Jason.encode!(summary))
    end
  end

  defp csv_bulk_upload_domains_summary(rows, %{updated: updated, errors: errors}) do
    %{
      "ids" => updated |> Enum.map(fn {_, {_, %{updated_ids: [id]}}} -> id end),
      "errors" =>
        errors
        |> Enum.map(fn error ->
          {index, field, message} =
            case error do
              {index, {:error, %{errors: [{field, {message, _}} | _]}}} ->
                {index, field, message}

              {index, {:error, {field, message}}} ->
                {index, field, message}
            end

          %{
            "external_id" =>
              Enum.find(rows, nil, fn
                {_, _, ^index} -> true
                _ -> false
              end)
              |> Tuple.to_list()
              |> Enum.at(0)
              |> Map.get("external_id"),
            "message" => %{field => [message]},
            "row" => index
          }
        end)
    }
  end

  def bulk_update_template_content(conn, params) do
    %{user_id: user_id} = claims = conn.assigns[:current_resource]
    structures_content_upload = Map.get(params, "structures")

    auto_publish = params |> Map.get("auto_publish", "false") |> String.to_existing_atom()

    with [_ | _] = contents <- BulkUpdate.from_csv(structures_content_upload, :simple),
         {:forbidden, []} <- {:forbidden, can_bulk_actions(contents, auto_publish, claims)},
         csv_hash <- FileHash.hash(structures_content_upload.path, :md5) do
      {code, response} =
        case BulkUpdater.bulk_csv_update(
               csv_hash,
               structures_content_upload,
               user_id,
               auto_publish
             ) do
          {:just_started, ^csv_hash, task_reference} ->
            {
              :accepted,
              %{csv_hash: csv_hash, status: "JUST_STARTED", task_reference: task_reference}
            }

          {:already_started, %CsvBulkUpdateEvent{csv_hash: ^csv_hash} = event} ->
            {:accepted,
             TdDdWeb.CsvBulkUpdateEventView.render("show.json", %{csv_bulk_update_event: event})}
        end

      conn
      |> put_resp_content_type("application/json", "utf-8")
      |> send_resp(code, Jason.encode!(response))
    end
  end

  defp get_messsage_from_error(%Ecto.Changeset{errors: errors}) do
    errors
    |> Enum.map(fn {k, v} ->
      case v do
        {_error, nested_errors} ->
          get_message_from_nested_errors(k, nested_errors)

        _ ->
          %{
            field: nil,
            message: "#{k}.default"
          }
      end
    end)
    |> List.flatten()
  end

  defp get_message_from_nested_errors(k, nested_errors) do
    Enum.map(nested_errors, fn {field, {_, [{_, e} | _]}} ->
      %{
        field: field,
        message: "#{k}.#{e}"
      }
    end)
  end

  defp can_bulk_actions(
         [{_content, %{data_structure: _, row_index: _}} | _] = contents,
         auto_publish,
         claims
       )
       when is_list(contents) do
    contents
    |> Enum.reject(fn
      {_content, %{data_structure: nil}} ->
        true

      {_content, %{data_structure: data_structure}} ->
        can_edit =
          case StructureNotesWorkflow.get_action_editable_action(data_structure) do
            :create -> permit?(StructureNotes, :create, claims, data_structure)
            :edit -> permit?(StructureNotes, :edit, claims, data_structure)
            _ -> true
          end

        if auto_publish do
          can_edit and
            permit?(StructureNotes, :publish_draft, claims, data_structure)
        else
          can_edit
        end
    end)
  end

  defp can_bulk_actions(contents, auto_publish, claims) do
    contents
    |> Enum.map(fn {_, data_structure, row_index} ->
      {%{}, %{data_structure: data_structure, row_index: row_index}}
    end)
    |> can_bulk_actions(auto_publish, claims)
  end

  defp search_all_structures(claims, permission, params) do
    params
    |> Map.put("without", "deleted_at")
    |> Map.drop(["page", "size"])
    |> Search.search_data_structures(claims, permission, 0, :infinity)
  end

  swagger_path :csv do
    description("Download CSV of structures")
    produces("application/json")

    parameters do
      search(:body, Schema.ref(:DataStructureSearchRequest), "Search query parameter")
    end

    response(200, "OK")
    response(403, "User is not authorized to perform this action")
    response(422, "Error while CSV download")
  end

  def csv(conn, params) do
    header_labels = Map.get(params, "header_labels", %{})
    params = Map.drop(params, ["header_labels", "page", "size"])

    permission = conn.assigns[:search_permission]
    claims = conn.assigns[:current_resource]

    %{results: data_structures} = search_all_structures(claims, permission, params)

    case data_structures do
      [] ->
        send_resp(conn, :no_content, "")

      _ ->
        conn
        |> put_resp_content_type("text/csv", "utf-8")
        |> put_resp_header("content-disposition", "attachment; filename=\"structures.zip\"")
        |> send_resp(:ok, Download.to_csv(data_structures, header_labels))
    end
  end

  def editable_csv(conn, params) do
    params = Map.drop(params, ["page", "size"])
    permission = conn.assigns[:search_permission]
    claims = conn.assigns[:current_resource]

    %{results: data_structures} = search_all_structures(claims, permission, params)

    case data_structures do
      [] ->
        send_resp(conn, :no_content, "")

      _ ->
        conn
        |> put_resp_content_type("text/csv", "utf-8")
        |> put_resp_header("content-disposition", "attachment; filename=\"structures.zip\"")
        |> send_resp(:ok, Download.to_editable_csv(data_structures))
    end
  end

  defp get_data_structure(id, enrich_attrs) do
    case DataStructures.get_latest_version(id, enrich_attrs) do
      nil ->
        DataStructures.get_data_structure!(id)

      dsv ->
        dsv
        |> Map.get(:data_structure)
        |> Map.merge(Map.take(dsv, @enrich_attrs))
        |> Map.merge(Map.take(dsv, @lift_attrs))
    end
  end

  defp do_render_data_structure(conn, _claims, nil) do
    render_error(conn, :not_found)
  end

  defp do_render_data_structure(conn, claims, data_structure) do
    if permit?(DataStructures, :view_data_structure, claims, data_structure) do
      user_permissions = %{
        update: can?(claims, update_data_structure(data_structure)),
        confidential:
          permit?(DataStructures, :manage_confidential_structures, claims, data_structure),
        view_profiling_permission: can?(claims, view_data_structures_profile(data_structure))
      }

      # TODO: tags not consumed by front?
      tags = Tags.tags(data_structure)

      render(conn, "show.json",
        data_structure: data_structure,
        user_permissions: user_permissions,
        tags: tags
      )
    else
      render_error(conn, :forbidden)
    end
  end

  defp do_search(conn, params, page \\ 0, size \\ 50)

  defp do_search(_conn, %{"scroll" => _, "scroll_id" => _} = scroll_params, _page, _size) do
    Search.scroll_data_structures(scroll_params)
  end

  defp do_search(conn, search_params, page, size) do
    claims = conn.assigns[:current_resource]
    permission = conn.assigns[:search_permission]

    page = Map.get(search_params, "page", page)
    size = Map.get(search_params, "size", size)

    search_params
    |> deleted_structures()
    |> Map.drop(["page", "size"])
    |> Search.search_data_structures(claims, permission, page, size)
  end

  defp search_assigns(%{results: data_structures, scroll_id: scroll_id}) do
    [data_structures: data_structures, scroll_id: scroll_id]
  end

  defp search_assigns(%{results: data_structures, aggregations: aggregations}) do
    [data_structures: data_structures, filters: aggregations]
  end

  defp search_assigns(%{results: data_structures}) do
    [data_structures: data_structures]
  end

  defp deleted_structures(%{"filters" => %{"all" => true} = filters} = search_params) do
    filters = Map.delete(filters, "all")
    Map.put(search_params, "filters", filters)
  end

  defp deleted_structures(search_params) do
    filters = Map.delete(Map.get(search_params, "filters", %{}), "all")

    search_params
    |> Map.put("filters", filters)
    |> Map.put("without", "deleted_at")
  end

  defp put_actions(conn, params, total) do
    claims = conn.assigns[:current_resource]

    actions =
      params
      |> actions_notes(total)
      |> Enum.filter(&Bodyguard.permit?(StructureNotes, &1, claims))
      |> Enum.reduce(%{}, fn
        :bulk_update, acc ->
          Map.put(acc, "bulkUpdate", %{
            href: Routes.data_structure_path(conn, :bulk_update),
            method: "POST"
          })

        :bulk_upload, acc ->
          Map.put(acc, "bulkUpload", %{
            href: Routes.data_structure_path(conn, :bulk_update_template_content),
            method: "POST"
          })

        :auto_publish, acc ->
          Map.put(acc, "autoPublish", %{
            href: Routes.data_structure_path(conn, :bulk_update_template_content),
            method: "POST"
          })
      end)
      |> put_actions_structures(conn, claims)

    assign(conn, :actions, actions)
  end

  defp put_actions_structures(actions, conn, claims) do
    @structures_actions
    |> Enum.filter(&can?(claims, &1, DataStructure))
    |> Enum.reduce(%{}, fn
      :update_domain_ids, acc ->
        Map.put(acc, "bulkUploadDomains", %{
          href: Routes.data_structure_path(conn, :bulk_upload_domains),
          method: "POST"
        })
    end)
    |> Map.merge(actions)
  end

  defp actions_notes(%{"filters" => %{"type.raw" => [_]}} = _params, total) when total > 0 do
    [:bulk_upload, :auto_publish, :bulk_update]
  end

  defp actions_notes(_params, _), do: [:bulk_upload, :auto_publish]
end
