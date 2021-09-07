defmodule TdDdWeb.Schema.Middleware.Authorize do
  @moduledoc """
  Absinthe authorization middleware
  """

  @behaviour Absinthe.Middleware

  import Canada.Can, only: [can?: 3]

  alias Absinthe.Resolution

  def call(%{state: :resolved} = resolution, _opts) do
    resolution
  end

  def call(%{context: context} = resolution, opts) do
    with %{claims: claims} <- context,
         action when not is_nil(action) <- Keyword.get(opts, :action),
         resource when not is_nil(resource) <- Keyword.get(opts, :resource),
         {:can, true} <- {:can, can?(claims, action, resource)} do
      resolution
    else
      {:can, _} -> Resolution.put_result(resolution, {:error, :forbidden})
      _ -> Resolution.put_result(resolution, {:error, :unauthorized})
    end
  end
end
