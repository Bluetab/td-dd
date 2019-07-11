defmodule TreeTest do
    alias TdCache.TaxonomyCache
    alias TdDd.CSV.Reader
    alias TdDd.Systems
    alias TdDd.DataStructures.Tree
  
    require Logger
  
  
    @structure_import_schema Application.get_env(:td_dd, :metadata)[:structure_import_schema]
    @structure_import_required Application.get_env(:td_dd, :metadata)[:structure_import_required]
    @field_import_schema Application.get_env(:td_dd, :metadata)[:field_import_schema]
    @field_import_required Application.get_env(:td_dd, :metadata)[:field_import_required]
    @relation_import_schema Application.get_env(:td_dd, :metadata)[:relation_import_schema]
    @relation_import_required Application.get_env(:td_dd, :metadata)[:relation_import_required]
    
    def run do
      {:ok, structures} = parse_data_structures("/Users/tomc/src/true-dat/td-dd/data/20190710-ll1tseunesdbentities/structures.csv", nil)
      {:ok, fields} = parse_data_fields("/Users/tomc/src/true-dat/td-dd/data/20190710-ll1tseunesdbentities/fields.csv", nil)
      {:ok, rels} = parse_data_structure_relations("/Users/tomc/src/true-dat/td-dd/data/20190710-ll1tseunesdbentities/relations.csv", nil)
      tree = Tree.new(structures, fields, rels)
    end

    defp parse_data_structures(path, system_id) do
      domain_map = TaxonomyCache.get_domain_name_to_id_map()
      system_map = get_system_map(system_id)
  
      defaults =
        case system_id do
          nil -> %{version: 0}
          _ -> %{system_id: system_id, version: 0}
        end
  
      path
      |> File.stream!()
      |> Reader.read_csv(
        domain_map: domain_map,
        system_map: system_map,
        defaults: defaults,
        schema: @structure_import_schema,
        required: @structure_import_required
      )
    end
  
    defp parse_data_fields(path, system_id) do
      defaults =
        case system_id do
          nil -> %{version: 0, external_id: nil}
          _ -> %{version: 0, external_id: nil, system_id: system_id}
        end
  
      system_map = get_system_map(system_id)
  
      path
      |> File.stream!()
      |> Reader.read_csv(
        defaults: defaults,
        system_map: system_map,
        schema: @field_import_schema,
        required: @field_import_required,
        booleans: ["nullable"]
      )
    end
  
    defp parse_data_structure_relations(path, system_id) do
      system_map = get_system_map(system_id)
  
      defaults =
        case system_id do
          nil -> %{}
          _ -> %{system_id: system_id}
        end
  
      path
      |> File.stream!()
      |> Reader.read_csv(
        defaults: defaults,
        system_map: system_map,
        schema: @relation_import_schema,
        required: @relation_import_required
      )
    end
  
    defp get_system_map(nil), do: Systems.get_system_name_to_id_map()
    defp get_system_map(_system_id), do: nil
  
  
end
