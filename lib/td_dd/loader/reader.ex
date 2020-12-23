defmodule TdDd.Loader.Reader do
  @moduledoc """
  Reads data structure, data fields and relation records from CSV files
  """

  alias TdCache.TaxonomyCache
  alias TdDd.CSV.Reader
  alias TdDd.Systems

  @structure_import_schema Application.compile_env(:td_dd, :metadata)[:structure_import_schema]
  @structure_import_required Application.compile_env(:td_dd, :metadata)[
                               :structure_import_required
                             ]
  @structure_import_boolean Application.compile_env(:td_dd, :metadata)[:structure_import_boolean]
  @field_import_schema Application.compile_env(:td_dd, :metadata)[:field_import_schema]
  @field_import_required Application.compile_env(:td_dd, :metadata)[:field_import_required]
  @relation_import_schema Application.compile_env(:td_dd, :metadata)[:relation_import_schema]
  @relation_import_required Application.compile_env(:td_dd, :metadata)[:relation_import_required]

  def read(structures_file, fields_file, relations_file, domain, system_id) do
    with {:ok, fields} <- parse_data_fields(fields_file, system_id),
         {:ok, structures} <- parse_data_structures(structures_file, system_id, domain),
         {:ok, relations} <- parse_data_structure_relations(relations_file, system_id) do
      {:ok, %{fields: fields, relations: relations, structures: structures}}
    else
      _ -> {:error, :invalid}
    end
  end

  defp parse_data_structures(nil, _, _), do: {:ok, []}

  defp parse_data_structures(path, system_id, domain) do
    domain_external_ids = TaxonomyCache.get_domain_external_id_to_id_map()
    system_map = get_system_map(system_id)

    defaults =
      case system_id do
        nil -> %{}
        _ -> %{system_id: system_id}
      end

    records =
      path
      |> File.stream!()
      |> Reader.read_csv(
        domain_external_ids: domain_external_ids,
        domain: domain,
        system_map: system_map,
        defaults: defaults,
        schema: @structure_import_schema,
        required: @structure_import_required,
        booleans: @structure_import_boolean
      )

    File.rm("#{path}")
    records
  end

  defp parse_data_fields(nil, _), do: {:ok, []}

  defp parse_data_fields(path, system_id) do
    defaults =
      case system_id do
        nil -> %{external_id: nil}
        _ -> %{external_id: nil, system_id: system_id}
      end

    system_map = get_system_map(system_id)

    records =
      path
      |> File.stream!()
      |> Reader.read_csv(
        defaults: defaults,
        system_map: system_map,
        schema: @field_import_schema,
        required: @field_import_required,
        booleans: ["nullable"]
      )

    File.rm("#{path}")
    records
  end

  defp parse_data_structure_relations(nil, _), do: {:ok, []}

  defp parse_data_structure_relations(path, system_id) do
    system_map = get_system_map(system_id)

    defaults =
      case system_id do
        nil -> %{}
        _ -> %{system_id: system_id}
      end

    records =
      path
      |> File.stream!()
      |> Reader.read_csv(
        defaults: defaults,
        system_map: system_map,
        schema: @relation_import_schema,
        required: @relation_import_required
      )

    File.rm("#{path}")
    records
  end

  defp get_system_map(nil), do: Systems.get_system_name_to_id_map()
  defp get_system_map(_system_id), do: nil
end
