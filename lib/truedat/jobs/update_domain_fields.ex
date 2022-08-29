defmodule Truedat.Jobs.UpdateDomainFields do
  @moduledoc """
  Runtime migration of domain content fields. Domain fields which are nested
  documents will be replaced by the domain id (or a list of ids if multiple
  nested documents exist).
  """

  import Ecto.Query

  alias Ecto.Multi
  alias TdCache.TemplateCache
  alias TdCx.Sources.Source
  alias TdDd.DataStructures.StructureNote
  alias TdDd.Repo
  alias TdDd.Systems.System
  alias TdDq.Executions.Group
  alias TdDq.Implementations.Implementation
  alias TdDq.Remediations.Remediation
  alias TdDq.Rules.Rule

  require Logger

  def run do
    Task.Supervisor.start_child(TdDd.TaskSupervisor, &update_execution_groups/0)
    Task.Supervisor.start_child(TdDd.TaskSupervisor, &update_implementations/0)
    Task.Supervisor.start_child(TdDd.TaskSupervisor, &update_notes/0)
    Task.Supervisor.start_child(TdDd.TaskSupervisor, &update_remediations/0)
    Task.Supervisor.start_child(TdDd.TaskSupervisor, &update_rules/0)
    Task.Supervisor.start_child(TdDd.TaskSupervisor, &update_sources/0)
    Task.Supervisor.start_child(TdDd.TaskSupervisor, &update_systems/0)
  end

  defp update_execution_groups, do: update_content("qe", Group)
  defp update_implementations, do: update_content("ri", Implementation)
  defp update_notes, do: update_content("dd", StructureNote)
  defp update_remediations, do: update_content("remediation", Remediation)
  defp update_rules, do: update_content("dq", Rule)
  defp update_sources, do: update_content("cx", Source, :config)
  defp update_systems, do: update_content("dd", System)

  defp update_content(scope, schema, prop \\ :df_content) do
    fields = domain_fields(scope)

    fields
    |> list(schema)
    |> Enum.reduce(Multi.new(), &update_content(schema, &2, &1, fields, prop))
    |> Repo.transaction()
    |> maybe_log(schema)
  end

  defp domain_fields(scope) do
    TemplateCache.list_by_scope!(scope)
    |> Enum.flat_map(&do_domain_fields/1)
    |> Enum.uniq()
  end

  defp do_domain_fields(%{content: [_ | _] = content}) do
    Enum.flat_map(content, &do_domain_fields/1)
  end

  defp do_domain_fields(%{"fields" => [_ | _] = fields}) do
    Enum.flat_map(fields, &do_domain_fields/1)
  end

  defp do_domain_fields(%{"type" => "domain", "name" => name}), do: [name]

  defp do_domain_fields(_), do: []

  defp maybe_log({:ok, res}, schema) when map_size(res) > 0 do
    source = schema.__schema__(:source)
    Logger.info("Updated domain fields in #{source}: #{map_size(res)} rows updated")
  end

  defp maybe_log({:ok, _}, _), do: :ok

  defp list([], _schema), do: []

  defp list(fields, schema) do
    Enum.map(fields, &where_domain_field(schema, &1))
    |> Enum.reduce(fn q, acc -> union(acc, ^q) end)
    |> distinct(true)
    |> Repo.all()
  end

  defp where_domain_field(Source, f) do
    Source
    |> where([d], not is_nil(d.config[^f]["external_id"]) and not is_nil(d.config[^f]["id"]))
    |> or_where(
      [d],
      not is_nil(d.config[^f][0]["external_id"]) and not is_nil(d.config[^f][0]["id"])
    )
  end

  defp where_domain_field(schema, f) do
    schema
    |> where(
      [d],
      not is_nil(d.df_content[^f]["external_id"]) and not is_nil(d.df_content[^f]["id"])
    )
    |> or_where(
      [d],
      not is_nil(d.df_content[^f][0]["external_id"]) and not is_nil(d.df_content[^f][0]["id"])
    )
  end

  defp update_content(schema, multi, %{id: id} = struct, fields, prop) do
    queryable =
      schema
      |> where(id: ^id)
      |> select([bcv], field(bcv, ^prop))

    Multi.update_all(multi, id, queryable,
      set: [{prop, map_content(Map.get(struct, prop), fields)}]
    )
  end

  defp map_content(nil, _fields), do: nil

  defp map_content(%{} = content, fields) do
    fields
    |> Enum.filter(&Map.has_key?(content, &1))
    |> Enum.reduce(content, fn field, content ->
      Map.update!(content, field, fn
        [_ | _] = values -> Enum.map(values, &get_id/1)
        %{"id" => _} = value -> get_id(value)
      end)
    end)
  end

  defp get_id(%{"id" => id}) when is_integer(id), do: id
  defp get_id(%{"id" => id}) when is_binary(id), do: String.to_integer(id)
end
