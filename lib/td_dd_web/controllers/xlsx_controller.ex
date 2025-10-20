defmodule TdDdWeb.DataStructures.XLSXController do
  use TdDdWeb, :controller

  alias TdCore.Utils.FileHash
  alias TdDd.DataStructures

  alias TdDd.DataStructures.{
    DataStructure,
    DataStructureVersion,
    FileBulkUpdateEvent,
    FileBulkUpdateEvents,
    Search,
    StructureNotes
  }

  alias TdDd.XLSX.{Download, Upload}

  plug(TdDdWeb.SearchPermissionPlug)
  action_fallback(TdDdWeb.FallbackController)

  @default_lang Application.compile_env(:td_dd, :lang)

  def download(conn, params) do
    structure_url_schema = Map.get(params, "structure_url_schema", nil)
    opts = build_opts(params)

    params =
      Map.drop(params, [
        "page",
        "size",
        "structure_url_schema",
        "download_type",
        "note_type",
        "lang",
        "header_labels"
      ])

    permission = conn.assigns[:search_permission]
    claims = conn.assigns[:current_resource]

    with %{results: [_ | _] = data_structures} <-
           search_all_structures(claims, permission, params),
         {:ok, {file_name, blob}} <-
           Download.write_to_memory(data_structures, structure_url_schema, opts) do
      send_xlsx_file(conn, file_name, blob)
    else
      %{results: []} -> send_resp(conn, :no_content, "")
    end
  end

  def upload(conn, params) do
    %{user_id: user_id} = claims = conn.assigns[:current_resource]

    lang = Map.get(params, "lang", @default_lang)
    %{path: path, filename: filename} = Map.get(params, "structures")
    auto_publish = Map.get(params, "auto_publish", "false") == "true"

    opts = %{
      "auto_publish" => auto_publish,
      "lang" => lang,
      "user_id" => user_id,
      "claims" => claims
    }

    with hash when is_binary(hash) <- FileHash.hash(path, :md5),
         {:ok, %Oban.Job{id: id}} <-
           Upload.structures_async(%{path: path, filename: filename}, hash, opts),
         {:ok, %FileBulkUpdateEvent{status: "PENDING"}} <-
           FileBulkUpdateEvents.create_pending(user_id, hash, filename, "oban:#{id}") do
      send_resp(conn, :accepted, "")
    end
  end

  def download_notes(conn, %{"data_structure_id" => data_structure_id} = params) do
    lang = Map.get(params, "lang", @default_lang)
    statuses = Map.get(params, "statuses", ["published"]) |> Enum.map(&String.to_existing_atom/1)
    include_children = Map.get(params, "include_children", false)
    claims = conn.assigns[:current_resource]

    id = String.to_integer(data_structure_id)

    with {:data_structure, %DataStructure{} = data_structure} <-
           {:data_structure, DataStructures.get_data_structure(id)},
         {:last_version, %DataStructureVersion{} = current_version} <-
           {:last_version, DataStructures.get_latest_version(data_structure)},
         {:permit, :ok} <-
           {:permit,
            Bodyguard.permit(DataStructures, :view_data_structure, claims, data_structure)} do
      {:ok, {file_name, blob}} =
        id
        |> StructureNotes.get_notes_with_hierarchy(statuses, current_version, include_children)
        |> Download.write_notes_to_memory(lang: lang)

      send_xlsx_file(conn, file_name, blob)
    else
      {:data_structure, nil} -> send_resp(conn, :not_found, "")
      {:last_version, nil} -> send_resp(conn, :not_found, "")
      {:permit, {:error, :unauthorized}} -> send_resp(conn, :forbidden, "")
      {:permit, {:error, :forbidden}} -> send_resp(conn, :forbidden, "")
      {:error, _} -> send_resp(conn, :unprocessable_entity, "")
    end
  end

  defp send_xlsx_file(conn, file_name, blob) do
    conn
    |> put_resp_content_type(
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;charset=utf-8"
    )
    |> put_resp_header("content-disposition", "attachment; filename=#{file_name}")
    |> send_resp(:ok, blob)
  end

  defp search_all_structures(claims, permission, params) do
    params
    |> Map.put("without", "deleted_at")
    |> Map.drop(["page", "size"])
    |> Search.scroll_data_structures(claims, permission)
  end

  defp build_opts(params) do
    params
    |> Map.take(["download_type", "note_type", "lang", "header_labels"])
    |> Keyword.new(fn
      {"download_type", "editable"} -> {:download_type, :editable}
      {"note_type", "published"} -> {:note_type, :published}
      {"note_type", "non_published"} -> {:note_type, :non_published}
      {"header_labels", header_labels} -> {:header_labels, header_labels}
      {"lang", lang} -> {:lang, lang}
    end)
    |> Keyword.put_new(:lang, @default_lang)
    |> Keyword.put_new(:header_labels, %{})
  end
end
