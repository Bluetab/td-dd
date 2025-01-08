defmodule TdDdWeb.Resolvers.CatalogViewConfigs do
  @moduledoc """
  Absinthe resolvers for grant approval rules
  """

  alias TdDd.DataStructures.CatalogViewConfig
  alias TdDd.DataStructures.CatalogViewConfigs
  alias TdDd.Utils.ChangesetUtils

  def catalog_view_configs(_parent, _args, resolution) do
    with {:claims, %{} = claims} <- {:claims, claims(resolution)},
         :ok <- Bodyguard.permit(CatalogViewConfigs, :view, claims) do
      {:ok, CatalogViewConfigs.list()}
    else
      {:claims, nil} -> {:error, :unauthorized}
      error -> error
    end
  end

  def catalog_view_config(_parent, %{id: id}, resolution) do
    with {:claims, %{} = claims} <- {:claims, claims(resolution)},
         :ok <- Bodyguard.permit(CatalogViewConfigs, :view, claims) do
      {:ok, CatalogViewConfigs.get(id)}
    else
      {:claims, nil} -> {:error, :unauthorized}
      error -> error
    end
  end

  def create_catalog_view_config(_parent, %{catalog_view_config: params}, resolution) do
    with {:claims, %{} = claims} <- {:claims, claims(resolution)},
         :ok <- Bodyguard.permit(CatalogViewConfigs, :manage, claims),
         {:ok, catalog_view_config} <- CatalogViewConfigs.create(params) do
      {:ok, catalog_view_config}
    else
      {:claims, nil} -> {:error, :unauthorized}
      {:error, changeset} -> {:error, ChangesetUtils.error_message_list_on(changeset)}
    end
  end

  def update_catalog_view_config(_parent, %{catalog_view_config: %{id: id} = params}, resolution) do
    with {:claims, %{} = claims} <- {:claims, claims(resolution)},
         :ok <- Bodyguard.permit(CatalogViewConfigs, :manage, claims),
         {:catalog_view_config, %CatalogViewConfig{} = catalog_view_config} <-
           {:catalog_view_config, CatalogViewConfigs.get(id)},
         {:ok, catalog_view_config} <- CatalogViewConfigs.update(catalog_view_config, params) do
      {:ok, catalog_view_config}
    else
      {:claims, nil} -> {:error, :unauthorized}
      {:catalog_view_config, nil} -> {:error, :not_found}
      {:error, :forbidden} -> {:error, :forbidden}
      {:error, changeset} -> {:error, ChangesetUtils.error_message_list_on(changeset)}
    end
  end

  def delete_catalog_view_config(_parent, %{id: id} = _args, resolution) do
    with {:claims, %{} = claims} <- {:claims, claims(resolution)},
         :ok <- Bodyguard.permit(CatalogViewConfigs, :delete, claims) do
      CatalogViewConfigs.delete_by_id(id)
    else
      {:claims, nil} -> {:error, :unauthorized}
      {:error, :forbidden} -> {:error, :forbidden}
    end
  end

  defp claims(%{context: %{claims: claims}}), do: claims
  defp claims(_), do: nil
end
