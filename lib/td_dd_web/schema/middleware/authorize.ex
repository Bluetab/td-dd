defmodule TdDdWeb.Schema.Middleware.Authorize do
  @moduledoc """
  Absinthe authorization middleware
  """

  @behaviour Absinthe.Middleware

  alias Absinthe.Resolution

  def call(%{state: :resolved} = resolution, _opts) do
    resolution
  end

  def call(%{context: context} = resolution, opts) do
    policy = Keyword.get(opts, :policy, TdDdWeb.Policy)

    with %{claims: claims} <- context,
         action when not is_nil(action) <- Keyword.get(opts, :action),
         resource when not is_nil(resource) <- Keyword.get(opts, :resource),
         :ok <- Bodyguard.permit(policy, action, claims, resource) do
      resolution
    else
      {:error, :forbidden} -> Resolution.put_result(resolution, {:error, :forbidden})
      _ -> Resolution.put_result(resolution, {:error, :unauthorized})
    end
  end
end
