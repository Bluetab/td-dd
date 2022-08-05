defmodule TdDq.Jobs.UpdateDomainFields do
  @moduledoc """
  Runtime migration of domain content fields. Domain fields which are nested
  documents will be replaced by the domain id (or a list of ids if multiple
  nested documents exist).
  """
  import Ecto.Query

  alias Ecto.Multi
  alias TdCx.Sources.Source
  alias TdDd.Repo
  alias TdDd.DataStructures.StructureNote
  alias TdDq.Implementations.Implementation
  alias TdDq.Rules.Rule
  alias TdCache.TemplateCache

  require Logger

  def run do
    # Task.Supervisor.start_child(TdDd.TaskSupervisor, fn -> update_rules() end)
    # Task.Supervisor.start_child(TdDd.TaskSupervisor, fn -> update_sources() end)
    # Task.Supervisor.start_child(TdDd.TaskSupervisor, fn -> update_implementations() end)
    TdDd.Repo.transaction(fn ->
      update_sources()
      update_rules()
      update_implementations()
      update_notes()
      # execution group
      # system
      # remediation
      TdDd.Repo.rollback(:ok)
    end)
  end

  defp update_notes, do: update_df_content("dd", StructureNote)
  defp update_implementations, do: update_df_content("ri", Implementation)
  defp update_rules, do: update_df_content("dq", Rule)

  defp update_sources do
    fields = domain_fields("cx")

    fields
    |> list(Source)
    |> Enum.reduce(Multi.new(), &update_config(&2, &1, fields))
    |> Repo.transaction()
    |> maybe_log(Source)
  end

  defp update_df_content(scope, schema) do
    fields = domain_fields(scope)

    fields
    |> list(schema)
    |> Enum.reduce(Multi.new(), &update_df_content(schema, &2, &1, fields))
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
    Logger.info("Updated domain fields in #{map_size(res)} #{source}")
  end

  defp maybe_log({:ok, _}, _), do: :ok

  defp list([], _schema), do: []

  defp list(fields, schema) do
    Enum.map(fields, fn f ->
      where_domain_field(schema, f)
    end)
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

  defp update_config(multi, %{config: content, id: id}, fields) do
    queryable =
      Source
      |> where(id: ^id)
      |> select([bcv], bcv.config)

    Multi.update_all(multi, id, queryable, set: [config: map_content(content, fields)])
  end

  defp update_df_content(schema, multi, %{df_content: content, id: id}, fields) do
    queryable =
      schema
      |> where(id: ^id)
      |> select([bcv], bcv.df_content)

    Multi.update_all(multi, id, queryable, set: [df_content: map_content(content, fields)])
  end

  defp map_content(content, fields) do
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
