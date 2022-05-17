defmodule TdDd.ReferenceData do
  @moduledoc """
  The Reference Data conext
  """

  import Ecto.Query

  alias TdDd.ReferenceData.Dataset
  alias TdDd.Repo

  @spec get!(binary | integer) :: Dataset.t()
  def get!(id) do
    dataset_query(id: id)
    |> Repo.one!()
  end

  @spec list :: [Dataset.t()]
  def list(args \\ %{}) do
    args
    |> dataset_query()
    |> Repo.all()
  end

  @spec create(binary(), binary()) :: {:ok, Dataset.t()} | {:error, Ecto.Changeset.t()}
  def create(name, path_or_upload) do
    %{name: name, data: read_data(path_or_upload)}
    |> Dataset.changeset()
    |> Repo.insert()
  end

  @spec update(Dataset.t(), binary()) :: {:ok, Dataset.t()} | {:error, Ecto.Changeset.t()}
  def update(%Dataset{} = dataset, path_or_upload) do
    dataset
    |> Dataset.changeset(%{data: read_data(path_or_upload)})
    |> Repo.update()
  end

  @spec delete(Dataset.t()) :: {:ok, Dataset.t()} | {:error, Ecto.Changeset.t()}
  def delete(%Dataset{} = dataset) do
    Repo.delete(dataset)
  end

  @spec read_data(binary()) :: [[binary()]]
  defp read_data(path) do
    path
    |> File.stream!(read_ahead: 100_000)
    |> CsvParser.parse_stream(skip_headers: false)
    |> Enum.to_list()
  end

  defp dataset_query(args) do
    queryable = select_merge(Dataset, [ds], %{row_count: fragment("array_length(?, 1)", ds.rows)})

    Enum.reduce(args, queryable, fn
      {:id, id}, q -> where(q, [ds], ds.id == ^id)
    end)
  end
end
