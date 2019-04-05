defmodule TdDd.Audit.AuditSupport do
  @moduledoc false

  alias TdDd.Audit
  alias TdDd.DataStructures.System
  alias TdDd.DataStructures.Systems

  @df_cache Application.get_env(:td_dd, :df_cache)

  def create_data_structure(conn, id, params) do
    create_data_structure_event(conn, id, params, "create_data_structure")
  end

  defp get_not_nil(nil, default), do: default
  defp get_not_nil(value, _), do: value

  def update_data_structure(conn, %{type: type} = old_data, %{"df_content" => _} = new_data) do
    content_changes = df_content_changes(old_data, new_data, @df_cache.get_template_by_name(type))

    payload =
      case content_changes do
        nil -> %{}
        content_changes -> %{"df_content" => content_changes}
      end

    create_data_structure_event(conn, old_data.id, payload, "update_data_structure")
  end

  def update_data_structure(conn, old_data, new_data) do
    create_data_structure_event(conn, old_data.id, new_data, "update_data_structure")
  end

  defp df_content_changes(old_data, new_data, %{content: template_content}) do
    field_labels =
      Enum.reduce(template_content, %{}, fn field, acc ->
        Map.put(acc, Map.get(field, "name"), Map.get(field, "label"))
      end)

    oldcontent = old_data |> Map.get(:df_content) |> get_not_nil(%{})
    newcontent = new_data |> Map.get("df_content") |> get_not_nil(%{})

    added_keys = Map.keys(newcontent) -- Map.keys(oldcontent)

    added =
      Enum.map(added_keys, fn key ->
        %{
          "label" => Map.get(field_labels, key),
          "field" => key,
          "value" => Map.get(newcontent, key)
        }
      end)

    removed_keys = Map.keys(oldcontent) -- Map.keys(newcontent)

    removed =
      Enum.map(removed_keys, fn key ->
        %{"field" => key, "value" => Map.get(oldcontent, key)}
      end)

    changed_keys = (Map.keys(newcontent) -- removed_keys) -- added_keys

    changed =
      changed_keys
      |> Enum.map(fn key ->
        case Map.get(oldcontent, key) == Map.get(newcontent, key) do
          true ->
            nil

          false ->
            %{
              "label" => Map.get(field_labels, key),
              "field" => key,
              "value" => Map.get(newcontent, key)
            }
        end
      end)
      |> Enum.filter(&(not is_nil(&1)))

    %{}
    |> Map.put(:added, added)
    |> Map.put(:removed, removed)
    |> Map.put(:changed, changed)
  end

  defp df_content_changes(_, _, _), do: nil

  def delete_data_structure(conn, id) do
    create_data_structure_event(conn, id, %{}, "delete_data_structure")
  end

  defp create_data_structure_event(conn, id, payload, event) do
    audit = %{
      "audit" => %{
        "resource_id" => id,
        "resource_type" => "data_structure",
        "payload" => payload
      }
    }

    Audit.create_event(conn, audit, event)
  end

  def system_created(conn, %System{id: id} = params) do
    create_system_event(conn, id, params, "create_system")
  end

  def system_updated(conn, %System{} = old, %System{id: id} = new) do
    params = old |> Systems.diff(new)
    create_system_event(conn, id, params, "update_system")
  end

  defp create_system_event(conn, resource_id, params, event) do
    payload = Map.take(params, [:external_id, :name])

    audit = %{
      "audit" => %{
        "resource_id" => resource_id,
        "resource_type" => "system",
        "payload" => payload
      }
    }

    Audit.create_event(conn, audit, event)
  end
end
