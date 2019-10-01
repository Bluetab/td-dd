alias Elasticsearch.Document
alias TdDd.DataStructures
alias TdDd.DataStructures.DataStructure
alias TdDd.Search.Indexable
alias TdCache.TaxonomyCache
alias TdCache.TemplateCache
alias TdCache.UserCache
alias TdDfLib.Format

defimpl Document, for: DataStructure do
  @impl Document
  def id(%{id: id}), do: id

  @impl Document
  def routing(_), do: false

  @impl Document
  def encode(%DataStructure{}) do
    raise "Not implemented - use Indexable"
  end
end

defimpl Document, for: Indexable do
  @impl Document
  def id(%{data_structure: %{id: id}}), do: id

  @impl Document
  def routing(_), do: false

  @impl Document
  def encode(%Indexable{data_structure_version: dsv, data_structure: structure, system: system}) do
    last_change_by = get_user(structure.last_change_by)

    domain_ids =
      case structure.domain_id do
        nil -> []
        domain_id -> TaxonomyCache.get_parent_ids(domain_id)
      end

    path = DataStructures.get_path(dsv)

    data_fields =
      dsv
      |> Map.get(:data_fields, [])
      |> Enum.map(&Map.take(&1, [:id, :name]))

    system = Map.take(system, [:id, :external_id, :name])

    df_content = format_content(structure, dsv.type)

    structure
    |> Map.take([
      :id,
      :ou,
      :domain_id,
      :external_id,
      :system_id,
      :inserted_at,
      :updated_at,
      :confidential
    ])
    |> Map.put(:data_fields, data_fields)
    |> Map.put(:path, path)
    |> Map.put(:last_change_by, last_change_by)
    |> Map.put(:domain_ids, domain_ids)
    |> Map.put(:system, system)
    |> Map.put(:df_content, df_content)
    |> Map.put_new(:ou, "")
    |> Map.merge(
      Map.take(dsv, [
        :class,
        :description,
        :deleted_at,
        :group,
        :name,
        :type,
        :metadata
      ])
    )
  end

  defp get_user(user_id) do
    case UserCache.get(user_id) do
      {:ok, nil} -> %{}
      {:ok, user} -> user
    end
  end

  defp format_content(%DataStructure{df_content: nil}, _), do: nil

  defp format_content(%DataStructure{df_content: df_content}, _) when map_size(df_content) == 0,
    do: nil

  defp format_content(%DataStructure{df_content: df_content}, type) do
    format_content(df_content, TemplateCache.get_by_name!(type))
  end

  defp format_content(df_content, %{} = template_content) do
    df_content |> Format.search_values(template_content)
  end

  defp format_content(_, _), do: nil
end
