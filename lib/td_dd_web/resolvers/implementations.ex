defmodule TdDdWeb.Resolvers.Implementations do
  @moduledoc """
  Absinthe resolvers for implementations
  """

  import Canada, only: [can?: 2]

  alias TdDq.Implementations
  alias TdDq.Implementations.Workflow

  def submit_implementation(_parent, %{id: id}, resolution) do
    implementation = Implementations.get_implementation!(id)

    with {:status, :draft} <- {:status, implementation.status},
         {:last, true} <- {:last, Implementations.last?(implementation)},
         {:claims, %{} = claims} <- {:claims, claims(resolution)},
         {:can, true} <- {:can, can?(claims, send_for_approval(implementation))},
         {:ok, %{implementation: implementation}} <-
           Workflow.submit_implementation(implementation, claims) do
      {:ok, implementation}
    else
      {:status, _} -> {:error, :unprocessable_entity}
      {:last, false} -> {:error, :unprocessable_entity}
      {:claims, nil} -> {:error, :unauthorized}
      {:can, false} -> {:error, :forbidden}
      {:error, changeset} -> {:error, changeset}
      {:vault_error, error} -> {:error, error}
    end
  end

  def reject_implementation(_parent, %{id: id}, resolution) do
    implementation = Implementations.get_implementation!(id)

    with {:status, :pending_approval} <- {:status, implementation.status},
         {:last, true} <- {:last, Implementations.last?(implementation)},
         {:claims, %{} = claims} <- {:claims, claims(resolution)},
         {:can, true} <- {:can, can?(claims, reject_implementation(implementation))},
         {:ok, %{implementation: implementation}} <-
           Workflow.reject_implementation(implementation, claims) do
      {:ok, implementation}
    else
      {:status, _} -> {:error, :unprocessable_entity}
      {:last, false} -> {:error, :unprocessable_entity}
      {:claims, nil} -> {:error, :unauthorized}
      {:can, false} -> {:error, :forbidden}
      {:error, changeset} -> {:error, changeset}
      {:vault_error, error} -> {:error, error}
    end
  end

  def unreject_implementation(_parent, %{id: id}, resolution) do
    implementation = Implementations.get_implementation!(id)

    with {:status, :rejected} <- {:status, implementation.status},
         {:last, true} <- {:last, Implementations.last?(implementation)},
         {:claims, %{} = claims} <- {:claims, claims(resolution)},
         {:can, true} <- {:can, can?(claims, unreject_implementation(implementation))},
         {:ok, %{implementation: implementation}} <-
           Workflow.unreject_implementation(implementation, claims) do
      {:ok, implementation}
    else
      {:status, _} -> {:error, :unprocessable_entity}
      {:last, false} -> {:error, :unprocessable_entity}
      {:claims, nil} -> {:error, :unauthorized}
      {:can, false} -> {:error, :forbidden}
      {:error, changeset} -> {:error, changeset}
      {:vault_error, error} -> {:error, error}
    end
  end

  def publish_implementation(_parent, %{id: id}, resolution) do
    implementation = Implementations.get_implementation!(id)

    with {:status, :pending_approval} <- {:status, implementation.status},
         {:last, true} <- {:last, Implementations.last?(implementation)},
         {:claims, %{} = claims} <- {:claims, claims(resolution)},
         {:can, true} <- {:can, can?(claims, publish_implementation(implementation))},
         {:ok, %{implementation: implementation}} <-
           Workflow.publish_implementation(implementation, claims) do
      {:ok, implementation}
    else
      {:status, _} -> {:error, :unprocessable_entity}
      {:last, false} -> {:error, :unprocessable_entity}
      {:claims, nil} -> {:error, :unauthorized}
      {:can, false} -> {:error, :forbidden}
      {:error, changeset} -> {:error, changeset}
      {:vault_error, error} -> {:error, error}
    end
  end

  def deprecate_implementation(_parent, %{id: id}, resolution) do
    implementation = Implementations.get_implementation!(id)

    with {:status, :published} <- {:status, implementation.status},
         {:last, true} <- {:last, Implementations.last?(implementation)},
         {:claims, %{} = claims} <- {:claims, claims(resolution)},
         {:can, true} <- {:can, can?(claims, deprecate_implementation(implementation))},
         {:ok, %{implementation: implementation}} <-
           Workflow.deprecate_implementation(implementation, claims) do
      {:ok, implementation}
    else
      {:status, _} -> {:error, :unprocessable_entity}
      {:last, false} -> {:error, :unprocessable_entity}
      {:claims, nil} -> {:error, :unauthorized}
      {:can, false} -> {:error, :forbidden}
      {:error, changeset} -> {:error, changeset}
      {:vault_error, error} -> {:error, error}
    end
  end

  def publish_implementation_from_draft(_parent, %{id: id}, resolution) do
    implementation = Implementations.get_implementation!(id)

    with {:status, :draft} <- {:status, implementation.status},
         {:last, true} <- {:last, Implementations.last?(implementation)},
         {:claims, %{} = claims} <- {:claims, claims(resolution)},
         {:can, true} <- {:can, can?(claims, publish_implementation_from_draft(implementation))},
         {:ok, %{implementation: implementation}} <-
           Workflow.publish_implementation_from_draft(implementation, claims) do
      {:ok, implementation}
    else
      {:status, _} -> {:error, :unprocessable_entity}
      {:last, false} -> {:error, :unprocessable_entity}
      {:claims, nil} -> {:error, :unauthorized}
      {:can, false} -> {:error, :forbidden}
      {:error, changeset} -> {:error, changeset}
      {:vault_error, error} -> {:error, error}
    end
  end

  defp claims(%{context: %{claims: claims}}), do: claims
  defp claims(_), do: nil
end
