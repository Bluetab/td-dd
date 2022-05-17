defmodule TdDd.ReferenceData do
  @moduledoc """
  The Reference Data conext
  """

  alias Plug.Upload
  alias TdDd.ReferenceData.Dataset
  alias TdDd.Repo

  def create(name, path_or_upload) do
    %{name: name, data: read_data(path_or_upload)}
    |> Dataset.changeset()
    |> Repo.insert()
  end

  def update(%Dataset{} = dataset, path_or_upload) do
    dataset
    |> Dataset.changeset(%{data: read_data(path_or_upload)})
    |> Repo.update()
  end

  defp read_data(%Upload{path: path}), do: read_data(path)

  defp read_data(path) do
    path
    |> File.stream!(read_ahead: 100_000)
    |> CsvParser.parse_stream(skip_headers: false)
    |> Enum.to_list()
  end
end
