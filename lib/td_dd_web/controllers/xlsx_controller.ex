defmodule TdDdWeb.DataStructures.XLSXController do
  use TdDdWeb, :controller

  alias TdCore.Search.Permissions
  alias TdCore.Utils.FileHash
  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructureRelation
  alias TdDd.DataStructures.FileBulkUpdateEvent
  alias TdDd.DataStructures.FileBulkUpdateEvents
  alias TdDd.DataStructures.Search
  alias TdDd.DataStructures.StructureNotes
  alias TdDd.Repo
  alias TdDd.XLSX.Download
  alias TdDd.XLSX.Upload

  import Ecto.Query

  plug TdDdWeb.SearchPermissionPlug

  action_fallback TdDdWeb.FallbackController

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
      conn
      |> put_resp_content_type(
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;charset=utf-8"
      )
      |> put_resp_header("content-disposition", "attachment; filename=#{file_name}")
      |> send_resp(:ok, blob)
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

    permission = conn.assigns[:search_permission]
    claims = conn.assigns[:current_resource]

    resolved_permission = resolve_permission(claims, permission)

    with {:ok, structure_with_notes} <-
           get_structure_notes_with_children(
             data_structure_id,
             statuses,
             include_children,
             claims,
             resolved_permission
           ),
         {:ok, {file_name, blob}} <-
           Download.write_notes_to_memory(structure_with_notes, lang: lang) do
      conn
      |> put_resp_content_type(
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;charset=utf-8"
      )
      |> put_resp_header("content-disposition", "attachment; filename=#{file_name}")
      |> send_resp(:ok, blob)
    else
      {:error, :not_found} -> send_resp(conn, :not_found, "")
      {:error, :forbidden} -> send_resp(conn, :forbidden, "")
      {:error, _} -> send_resp(conn, :unprocessable_entity, "")
    end
  end

  defp resolve_permission(claims, permission) do
    permission_name = to_string(permission)

    [permission_name, "manage_confidential_structures"]
    |> Permissions.get_search_permissions(claims)
    |> Map.get(permission_name)
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

  defp get_structure_notes_with_children(
         data_structure_id,
         statuses,
         include_children,
         claims,
         permission
       ) do
    id = String.to_integer(data_structure_id)

    with %{} = data_structure <- DataStructures.get_data_structure(id),
         %{} = current_version <- DataStructures.get_latest_version(data_structure),
         true <- has_permission?(current_version, claims, permission) do
      main_notes =
        id
        |> StructureNotes.list_structure_notes(statuses)
        |> Repo.preload(:data_structure)

      children_notes =
        get_children_notes(current_version, include_children, statuses, claims, permission)

      {:ok,
       %{
         main: %{structure: current_version, notes: main_notes},
         children: children_notes
       }}
    else
      nil -> {:error, :not_found}
      false -> {:error, :forbidden}
      error -> error
    end
  end

  defp get_children_notes(_current_version, false, _statuses, _claims, _permission), do: []

  defp get_children_notes(current_version, true, statuses, claims, permission) do
    from(r in DataStructureRelation,
      where: r.parent_id == ^current_version.id,
      select: r.child_id
    )
    |> Repo.all()
    |> Enum.flat_map(fn child_id ->
      child_dsv = DataStructures.get_data_structure_version!(child_id)

      get_children_data(child_dsv, claims, permission, statuses)
    end)
  end

  defp get_children_data(%{deleted_at: deleted_at}, _claims, _permission, _statuses)
       when not is_nil(deleted_at),
       do: []

  defp get_children_data(%{data_structure_id: data_structure_id}, claims, permission, statuses) do
    full_child_version =
      data_structure_id
      |> DataStructures.get_data_structure()
      |> DataStructures.get_latest_version()

    if has_permission?(full_child_version, claims, permission) do
      child_notes =
        data_structure_id
        |> StructureNotes.list_structure_notes(statuses)
        |> Repo.preload(:data_structure)

      if Enum.empty?(child_notes) do
        []
      else
        [%{structure: full_child_version, notes: child_notes}]
      end
    end
  end

  defp has_permission?(%{data_structure: %{domain_ids: _domain_ids}}, _claims, :all), do: true

  defp has_permission?(
         %{data_structure: %{domain_ids: domain_ids}},
         _claims,
         permission_domain_ids
       )
       when is_list(permission_domain_ids) do
    Enum.any?(domain_ids, &(&1 in permission_domain_ids))
  end

  defp has_permission?(%{domain_ids: _domain_ids}, _claims, :all), do: true

  defp has_permission?(%{domain_ids: domain_ids}, _claims, permission_domain_ids)
       when is_list(permission_domain_ids) do
    Enum.any?(domain_ids, &(&1 in permission_domain_ids))
  end

  defp has_permission?(_, _, _), do: false
end
