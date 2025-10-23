defmodule TdDdWeb.DataStructures.XLSXController do
  use TdDdWeb, :controller

  alias TdCore.Utils.FileHash

  alias TdDd.DataStructures.{
    FileBulkUpdateEvent,
    FileBulkUpdateEvents,
    Search
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

  defp send_xlsx_file(conn, file_name, blob) do
    conn
    |> put_resp_content_type(
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;charset=utf-8"
    )
    |> put_resp_header("content-disposition", "attachment; filename=#{file_name}")
    |> send_resp(:ok, blob)
  end

  defp search_all_structures(claims, permission, params) do
    include_children = to_string(Map.get(params, "include_children", false))
    data_structure_id = Map.get(params, "data_structure_id")

    params
    |> Map.put("without", "deleted_at")
    |> maybe_put_structure_filters(data_structure_id, include_children)
    |> Map.drop(["page", "size", "data_structure_id", "include_children"])
    |> Search.scroll_data_structures(claims, permission)
  end

  defp maybe_put_structure_filters(params, nil, _include_children), do: params

  defp maybe_put_structure_filters(params, data_structure_id, "false") do
    Map.put(params, "must", %{"data_structure_id" => data_structure_id})
  end

  defp maybe_put_structure_filters(params, data_structure_id, "true") do
    params
    |> Map.put("query", "#{data_structure_id}")
    |> Map.put("search_fields", ["data_structure_id", "parent_id"])
    |> Map.put("operator", "OR")
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
