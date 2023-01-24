defmodule TdDd.ReferenceData do
  @moduledoc """
  The Reference Data conext
  """

  import Ecto.Query

  alias TdDd.ReferenceData.Dataset
  alias TdDd.Repo

  defdelegate authorize(action, user, params), to: __MODULE__.Policy

  @spec get!(binary | integer) :: Dataset.t()
  def get!(id) do
    dataset_query(id: id)
    |> Repo.one!()
  end

  def exists?(id) do
    dataset_query(id: id)
    |> Repo.exists?()
  end

  @spec list :: [Dataset.t()]
  def list(args \\ %{}) do
    args
    |> dataset_query()
    |> Repo.all()
  end

  @spec create(map()) :: {:ok, Dataset.t()} | {:error, Ecto.Changeset.t()}
  def create(%{name: name, domain_ids: domain_ids} = args) do
    case read_data(args) do
      :none -> %{name: name, domain_ids: domain_ids}
      data -> %{name: name, domain_ids: domain_ids, data: data}
    end
    |> Dataset.changeset()
    |> Repo.insert()
  end

  @spec update(Dataset.t(), map()) :: {:ok, Dataset.t()} | {:error, Ecto.Changeset.t()}
  def update(%Dataset{} = dataset, %{name: name, domain_ids: domain_ids} = args) do
    params =
      case read_data(args) do
        :none -> %{name: name, domain_ids: domain_ids}
        data -> %{name: name, domain_ids: domain_ids, data: data}
      end

    dataset
    |> Dataset.changeset(params)
    |> Repo.update()
  end

  @spec delete(Dataset.t()) :: {:ok, Dataset.t()} | {:error, Ecto.Changeset.t()}
  def delete(%Dataset{} = dataset) do
    Repo.delete(dataset)
  end

  @spec to_csv(Dataset.t()) :: binary()
  def to_csv(%Dataset{headers: headers, rows: rows}) do
    [headers | rows]
    |> CSV.encode(separator: ?;)
    |> Enum.to_list()
    |> List.to_string()
  end

  @spec read_data(map()) :: [[binary()]] | :none
  defp read_data(%{path: path}) when is_binary(path), do: read_file(path)
  defp read_data(%{data: data}) when is_binary(data), do: read_string(data)
  defp read_data(_), do: :none

  @spec read_file(binary()) :: [[binary()]]
  defp read_file(path) do
    path
    |> File.stream!(read_ahead: 100_000)
    |> CsvParser.parse_stream(skip_headers: false)
    |> Enum.to_list()
  end

  @spec read_string(binary()) :: [[binary()]]
  defp read_string(data) do
    data
    |> CsvParser.parse_string(skip_headers: false)
    |> Enum.to_list()
  end

  defp dataset_query(args) do
    queryable = select_merge(Dataset, [ds], %{row_count: fragment("array_length(?, 1)", ds.rows)})

    Enum.reduce(args, queryable, fn
      {:id, id}, q -> where(q, [ds], ds.id == ^id)
      {:domain_ids, :all}, q -> q
      {:domain_ids, domain_ids}, q -> where(q, [ds], fragment("? && ?", ds.domain_ids, ^domain_ids))
    end)
  end
end
