defmodule TdDd.Loader.Reader do
  @moduledoc """
  Reads data structure, data fields and relation records from CSV files
  """

  alias Ecto.Changeset
  alias TdCache.DomainCache
  alias TdDd.CSV.Reader
  alias TdDd.Systems

  @type system :: Systems.System.t()

  @structure_import_schema Application.compile_env(:td_dd, :metadata)[:structure_import_schema]
  @structure_import_required Application.compile_env(:td_dd, :metadata)[
                               :structure_import_required
                             ]
  @structure_import_boolean Application.compile_env(:td_dd, :metadata)[:structure_import_boolean]
  @field_import_schema Application.compile_env(:td_dd, :metadata)[:field_import_schema]
  @field_import_required Application.compile_env(:td_dd, :metadata)[:field_import_required]
  @relation_import_schema Application.compile_env(:td_dd, :metadata)[:relation_import_schema]
  @relation_import_required Application.compile_env(:td_dd, :metadata)[:relation_import_required]
  @metadata_import_schema %{external_id: :string, mutable_metadata: :map}

  def read(structures_file, fields_file, relations_file, domain_external_id, system_id) do
    with {:ok, fields} <- parse_data_fields(fields_file, system_id),
         {:ok, structures} <-
           parse_data_structures(structures_file, system_id, domain_external_id),
         {:ok, relations} <- parse_data_structure_relations(relations_file, system_id) do
      {:ok, %{fields: fields, relations: relations, structures: structures}}
    end
  end

  @spec enrich_data_structures!(system, binary | nil, [map]) :: [map]
  def enrich_data_structures!(system, maybe_domain_external_id, data_structures)

  def enrich_data_structures!(system, nil, data_structures) do
    do_enrich_data_structures!(system, nil, data_structures)
  end

  def enrich_data_structures!(system, domain_external_id, data_structures) do
    case DomainCache.external_id_to_id(domain_external_id) do
      {:ok, domain_id} -> do_enrich_data_structures!(system, domain_id, data_structures)
    end
  end

  @spec do_enrich_data_structures!(system, integer | nil, [map]) :: [map]
  defp do_enrich_data_structures!(system, domain_id, data_structures) do
    Enum.map(data_structures, fn data_structure ->
      {%{}, @structure_import_schema}
      |> Changeset.cast(data_structure, Map.keys(@structure_import_schema))
      |> Changeset.put_change(:domain_ids, List.wrap(domain_id))
      |> Changeset.put_change(:system_id, system.id)
      |> Changeset.validate_required(@structure_import_required)
      |> put_default_metadata()
      |> case do
        %{valid?: true, changes: changes} -> changes
      end
    end)
  end

  def read_metadata_records(records) do
    records
    |> Enum.with_index(1)
    |> Enum.map(&validate_metadata_record/1)
    |> Enum.group_by(fn {res, _} -> res end, fn {_, value} -> value end)
    |> case do
      %{error: changesets} -> {:error, Enum.map(changesets, &Changeset.get_field(&1, :pos))}
      %{ok: records} -> {:ok, records}
    end
  end

  defp validate_metadata_record({%{} = params, pos}) do
    {%{pos: pos}, @metadata_import_schema}
    |> Changeset.cast(params, [:external_id, :mutable_metadata])
    |> Changeset.validate_required([:external_id, :mutable_metadata])
    |> Changeset.apply_action(:insert)
  end

  @spec put_default_metadata(Changeset.t()) :: Changeset.t()
  defp put_default_metadata(%Changeset{changes: %{metadata: _}} = changeset), do: changeset

  defp put_default_metadata(%Changeset{} = changeset) do
    Changeset.put_change(changeset, :metadata, %{})
  end

  @spec cast_data_structure_relations!([map]) :: [map]
  def cast_data_structure_relations!(relations) do
    Enum.map(relations, fn relation ->
      {%{}, @relation_import_schema}
      |> Changeset.cast(relation, Map.keys(@relation_import_schema))
      |> Changeset.validate_required(@relation_import_required)
      |> case do
        %{valid?: true, changes: changes} -> changes
      end
    end)
  end

  defp parse_data_structures(nil, _, _), do: {:ok, []}

  defp parse_data_structures(path, system_id, domain_external_id)
       when is_binary(domain_external_id) do
    domain = TdCache.TaxonomyCache.get_by_external_id(domain_external_id)
    parse_data_structures(path, system_id, domain)
  end

  defp parse_data_structures(path, system_id, domain) do
    domain_ids = domain_ids(domain)
    system_map = get_system_map(system_id)

    defaults =
      case system_id do
        nil -> %{domain_ids: domain_ids}
        _ -> %{system_id: system_id, domain_ids: domain_ids}
      end

    records =
      path
      |> File.stream!()
      |> Reader.read_csv(
        system_map: system_map,
        defaults: defaults,
        schema: @structure_import_schema,
        required: @structure_import_required,
        booleans: @structure_import_boolean
      )

    File.rm("#{path}")
    records
  end

  defp domain_ids(%{id: domain_id}) when is_integer(domain_id), do: [domain_id]
  defp domain_ids(_), do: []

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
