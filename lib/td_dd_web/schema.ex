defmodule TdDdWeb.Schema do
  @moduledoc """
  Absinthe Schema definitions
  """

  use Absinthe.Schema

  alias TdDdWeb.Schema.Middleware

  import_types(Absinthe.Plug.Types)
  import_types(Absinthe.Type.Custom)
  import_types(TdDdWeb.Schema.Structures)
  import_types(TdDdWeb.Schema.Types.Custom.JSON)

  query do
    import_fields(:structure_queries)
  end

  def context(ctx) do
    loader =
      Dataloader.new()
      |> Dataloader.add_source(TdDd.DataStructures, TdDd.DataStructures.datasource())

    Map.put(ctx, :loader, loader)
  end

  def middleware(middleware, %{identifier: field}, %{identifier: :query}) do
    [
      {Middleware.Authorize, [action: :query, resource: field]} | middleware
    ]
  end

  def middleware(middleware, _field, _obj), do: middleware

  def plugins do
    [Absinthe.Middleware.Dataloader | Absinthe.Plugin.defaults()]
  end
end
