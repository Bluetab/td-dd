defmodule TdDd.DataStructures.CatalogViewConfigs do
  @moduledoc """
  CatalogViewConfigs context
  """

  alias TdDd.DataStructures.CatalogViewConfig
  alias TdDd.Repo

  defdelegate authorize(action, user, params), to: __MODULE__.Policy

  import Ecto.Query

  def list, do: Repo.all(CatalogViewConfig)

  def get(id), do: Repo.get(CatalogViewConfig, id)

  def create(params) do
    CatalogViewConfig.changeset(params)
    |> Repo.insert()
  end

  def update(%CatalogViewConfig{} = catalog_view_config, %{} = params) do
    catalog_view_config
    |> CatalogViewConfig.changeset(params)
    |> Repo.update()
  end

  def delete_by_id(id) do
    query =
      CatalogViewConfig
      |> select([cvc], cvc)
      |> where([cvc], cvc.id == ^id)

    case Repo.delete_all(query) do
      {0, _} -> {:error, :not_found}
      {1, [what]} -> {:ok, what}
    end
  end
end
