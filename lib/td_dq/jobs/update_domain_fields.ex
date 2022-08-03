defmodule TdDq.Jobs.UpdateDomainFields do
  @moduledoc """
  Runtime migration of domain content fields. Domain fields which are nested
  documents will be replaced by the domain id (or a list of ids if multiple
  nested documents exist).
  """
  import Ecto.Query

  alias Ecto.Multi
  alias TdDd.Repo
  alias TdDq.Rules.Rule
  alias TdCache.TemplateCache

  require Logger

  def run do
    fields =
      TemplateCache.list_by_scope!("dq")
      |> Enum.flat_map(&domain_fields/1)
      |> IO.inspect()

    fields
    |> list_rules()
    |> Enum.reduce(Multi.new(), &update_domain_fields(&2, &1, fields))
    |> Repo.transaction()
    |> maybe_log()
  end

  defp domain_fields(%{content: [_ | _] = content}) do
    Enum.flat_map(content, &domain_fields/1)
  end

  defp domain_fields(%{"fields" => [_ | _] = fields}) do
    Enum.flat_map(fields, &domain_fields/1)
  end

  defp domain_fields(%{"type" => "domain", "name" => name}), do: [name]

  defp domain_fields(_), do: []

  defp maybe_log({:ok, res}) when map_size(res) > 0 do
    Logger.info("Updated domain fields in #{map_size(res)} concepts")
  end

  defp maybe_log({:ok, _}), do: :ok

  defp list_rules([]), do: []

  defp list_rules(fields) do
    Enum.map(fields, fn field ->
      Rule
      |> where(
        [r],
        not is_nil(r.df_content[^field][0]["external_id"]) and
          not is_nil(r.df_content[^field][0]["id"])
      )
      |> or_where(
        [r],
        not is_nil(r.df_content[^field]["external_id"]) and not is_nil(r.df_content[^field]["id"])
      )
    end)
    |> Enum.reduce(fn q, acc -> union(acc, ^q) end)
    |> distinct(true)
    |> Repo.all()
  end

  defp update_domain_fields(multi, %{df_content: content, id: id}, fields) do
    queryable =
      Rule
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

  defp get_id(%{"id" => id}) when is_binary(id), do: id
  defp get_id(%{"id" => id}) when is_integer(id), do: to_string(id)
end
