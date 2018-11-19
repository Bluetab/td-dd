defmodule TdDd.Audit.AuditSupport do
  @moduledoc false

  alias TdDd.Audit

  @df_cache Application.get_env(:td_dd, :df_cache)
  @data_structure "data_structure"

  def create_data_structure(conn, id, params) do
    create_data_structure_event(conn, id, params, "update_data_structure")
  end

  defp get_not_nil(nil, default), do: default
  defp get_not_nil(value, default), do: value

  def update_data_structure(conn, old_data, %{"df_name" => df_name} = new_data) do
    fields_to_compare = ["description", "df_name"]
    diffs = Enum.reduce(fields_to_compare, %{}, fn field, acc ->
        with value when not is_nil(value) <- Map.get(new_data, field),
          false <- value == Map.get(old_data, String.to_atom(field)) do

          Map.put(acc, field, value)
        else
          _ -> acc
        end
      end)

    %{content: template_content} = @df_cache.get_template_by_name(df_name)
    field_labels = Enum.reduce(template_content, %{}, fn field, acc ->
        Map.put(acc, Map.get(field, "name"), Map.get(field, "label"))
      end)

    oldcontent = old_data |> Map.get(:df_content) |> get_not_nil(%{})
    newcontent = new_data |> Map.get("df_content") |> get_not_nil(%{})

    added_keys = Map.keys(newcontent) -- Map.keys(oldcontent)
    added = Enum.map(added_keys, fn key ->
        %{
          "label" => Map.get(field_labels, key),
          "field" => key,
          "value" => Map.get(newcontent, key)
        }
      end)

    removed_keys = Map.keys(oldcontent) -- Map.keys(newcontent)
    removed = Enum.map(removed_keys, fn key ->
        %{"field" => key, "value" => Map.get(oldcontent, key)}
      end)

    changed_keys = (Map.keys(newcontent) -- removed_keys) -- added_keys
    changed = changed_keys
      |> Enum.map(fn key ->
          case Map.get(oldcontent, key) == Map.get(newcontent, key) do
            true -> nil
            false ->
              %{
                "label" => Map.get(field_labels, key),
                "field" => key,
                "value" => Map.get(newcontent, key)
              }
          end
        end)
      |> Enum.filter(& not is_nil(&1))

    changed_content =
      %{}
      |> Map.put(:added, added)
      |> Map.put(:removed, removed)
      |> Map.put(:changed, changed)

    payload = Map.put(diffs, "df_content", changed_content)
    create_data_structure_event(conn, old_data.id, payload, "update_data_structure")
  end
  def update_data_structure(conn, old_data, new_data) do
    create_data_structure_event(conn, old_data.id, new_data, "update_data_structure")
  end

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
end
