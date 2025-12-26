defmodule TdDq.XLSX.Download do
  @moduledoc """
  Helper module to download structures published and pending (non-published) notes.

  """
  alias Elixlsx.Sheet
  alias Elixlsx.Workbook
  alias TdCache.DomainCache
  alias TdCache.TemplateCache
  alias TdDq.XLSX.Writer

  require Logger

  def write_to_memory(implementations, opts \\ []) do
    Logger.info("Start writing to memory")
    {:ok, domain_ext_id_map} = DomainCache.id_to_external_id_map()
    {:ok, domain_name_map} = DomainCache.id_to_name_map()

    {:ok, rule_templates} = TemplateCache.list_by_scope("dq")

    rule_templates_map =
      Enum.into(rule_templates, %{}, fn template -> {template.name, template} end)

    {:ok, implementation_templates} = TemplateCache.list_by_scope("ri")

    implementation_templates_map =
      Enum.into(implementation_templates, %{}, fn template -> {template.name, template} end)

    result =
      implementations
      |> Enum.map(fn implementation ->
        %{
          implementation
          | "domain" => %{
              "external_id" => Map.get(domain_ext_id_map, implementation["domain_id"]),
              "name" => Map.get(domain_name_map, implementation["domain_id"])
            }
        }
      end)
      |> enrich_templates(rule_templates_map, implementation_templates_map)
      |> implementation_information(opts)
      |> Writer.rows_by_implementation_template(opts)
      |> sheets()
      |> then(fn [_ | _] = sheets ->
        workbook = %Workbook{sheets: sheets}
        Elixlsx.write_to_memory(workbook, "implementations.xlsx")
      end)

    Logger.info("End writing to memory")
    result
  end

  defp enrich_templates(implementations, rule_templates_map, implementation_templates_map) do
    implementations
    |> Enum.group_by(&rule_type/1)
    |> Enum.flat_map(&enrich_rule_templates(&1, rule_templates_map))
    |> Enum.group_by(&implementation_type/1)
    |> Enum.flat_map(&enrich_implementation_templates(&1, implementation_templates_map))
  end

  defp enrich_rule_templates({nil, implementations}, _rule_templates_map), do: implementations

  defp enrich_rule_templates({type, implementations}, rule_templates_map) when is_binary(type) do
    template = Map.get(rule_templates_map, type)
    enrich_rule_templates({template, implementations}, rule_templates_map)
  end

  defp enrich_rule_templates({%{} = template, implementations}, _rule_templates_map) do
    Enum.map(implementations, fn %{"rule" => rule} = implementation ->
      %{implementation | "rule" => Map.put(rule, "template", template)}
    end)
  end

  defp enrich_implementation_templates({nil, implementations}, _implementation_templates_map),
    do: implementations

  defp enrich_implementation_templates({type, implementations}, implementation_templates_map)
       when is_binary(type) do
    template = Map.get(implementation_templates_map, type)
    enrich_implementation_templates({template, implementations}, implementation_templates_map)
  end

  defp enrich_implementation_templates(
         {%{} = template, implementations},
         _implementation_templates_map
       ) do
    Enum.map(implementations, &Map.put(&1, "template", template))
  end

  defp rule_type(%{"rule" => %{"df_name" => rule_type}}), do: rule_type
  defp rule_type(_), do: nil

  defp implementation_type(%{"df_name" => implementation_type}), do: implementation_type
  defp implementation_type(_), do: nil

  def implementation_information(implementations, opts \\ []) do
    case opts[:group_by_status] do
      true ->
        implementations
        |> group_by_status_and_template()

      _ ->
        implementations
        |> Enum.group_by(& &1["df_name"])
    end
  end

  # Groups implementations by status and template for separate sheets
  defp group_by_status_and_template(implementations) do
    implementations
    |> Enum.group_by(fn implementation ->
      status = get_implementation_status(implementation)
      template_name = implementation["df_name"] || "unknown"
      "#{template_name}_#{status}"
    end)
  end

  # Determines the status of an implementation
  defp get_implementation_status(implementation) do
    case implementation do
      %{"status" => "published"} -> "published"
      %{"status" => "deprecated"} -> "deprecated"
      %{"status" => "pending"} -> "draft"
      %{"status" => "draft"} -> "draft"
      # Default to draft for undefined status
      _ -> "draft"
    end
  end

  defp sheets(rows_by_template) do
    rows_by_template
    |> Enum.map(fn {template, rows} ->
      {sanitize_sheet_name(template), rows || []}
    end)
    |> make_unique_sheet_names()
    |> Enum.map(fn {name, rows} ->
      %Sheet{name: name, rows: rows}
    end)
  end

  defp make_unique_sheet_names(sheets) do
    sheets
    |> Enum.reduce({%{}, []}, fn {name, rows}, {used_names, result} ->
      unique_name = get_unique_name(name, used_names)
      new_used_names = Map.put(used_names, name, Map.get(used_names, name, 0) + 1)
      {new_used_names, [{unique_name, rows} | result]}
    end)
    |> elem(1)
    |> Enum.reverse()
  end

  defp get_unique_name(name, used_names) do
    count = Map.get(used_names, name, 0)

    if count == 0 do
      name
    else
      suffix = "_#{count}"
      max_base_length = 31 - String.length(suffix)
      truncated_name = String.slice(name, 0, max_base_length)
      "#{truncated_name}#{suffix}"
    end
  end

  defp sanitize_sheet_name(name) when is_binary(name) do
    name
    # Reemplazar caracteres no permitidos
    |> String.replace(~r/[[\]:*?\/\\]/, "_")
    # Limitar a 31 caracteres
    |> String.slice(0, 31)
    |> then(fn
      # Si queda vacío, usar un nombre por defecto
      "" -> "Sheet"
      name -> name
    end)
  end

  defp sanitize_sheet_name(_), do: "Sheet"
end
