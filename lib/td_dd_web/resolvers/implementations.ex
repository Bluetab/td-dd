defmodule TdDdWeb.Resolvers.Implementations do
  @moduledoc """
  Absinthe resolvers for implementations
  """

  import Canada, only: [can?: 2]

  alias TdDq.Events.QualityEvents
  alias TdDq.Implementations
  alias TdDq.Implementations.Workflow
  alias TdDq.Rules.RuleResults

  def implementation(_parent, %{id: id}, resolution) do
    with {:claims, %{} = claims} <- {:claims, claims(resolution)},
         implementation <- Implementations.get_implementation!(id),
         {:can, true} <- {:can, can?(claims, show(implementation))} do
      {:ok, implementation}
    else
      {:claims, nil} -> {:error, :unauthorized}
      {:can, false} -> {:error, :forbidden}
      {:error, :implementation, changeset, _} -> {:error, changeset}
    end
  end

  def versions(implementation, _args, _resolution) do
    {:ok, Implementations.get_versions(implementation)}
  end

  def results(implementation, _args, _resolution) do
    {:ok, RuleResults.get_by(implementation)}
  end

  def last_quality_event(%{id: id} = _implementation, _args, _resolution) do
    {:ok, QualityEvents.get_event_by_imp(id)}
  end

  def submit_implementation(_parent, %{id: id}, resolution) do
    implementation = Implementations.get_implementation!(id)

    with {:claims, %{} = claims} <- {:claims, claims(resolution)},
         {:can, true} <- {:can, can?(claims, submit(implementation))},
         {:ok, %{implementation: implementation}} <-
           Workflow.submit_implementation(implementation, claims) do
      {:ok, implementation}
    else
      {:claims, nil} -> {:error, :unauthorized}
      {:can, false} -> {:error, :forbidden}
      {:error, :implementation, changeset, _} -> {:error, changeset}
    end
  end

  def reject_implementation(_parent, %{id: id}, resolution) do
    implementation = Implementations.get_implementation!(id)

    with {:claims, %{} = claims} <- {:claims, claims(resolution)},
         {:can, true} <- {:can, can?(claims, reject(implementation))},
         {:ok, %{implementation: implementation}} <-
           Workflow.reject_implementation(implementation, claims) do
      {:ok, implementation}
    else
      {:claims, nil} -> {:error, :unauthorized}
      {:can, false} -> {:error, :forbidden}
      {:error, :implementation, changeset, _} -> {:error, changeset}
    end
  end

  def publish_implementation(_parent, %{id: id}, resolution) do
    implementation = Implementations.get_implementation!(id)

    with {:claims, %{} = claims} <- {:claims, claims(resolution)},
         {:can, true} <- {:can, can?(claims, publish(implementation))},
         {:ok, %{implementation: implementation}} <-
           Workflow.publish_implementation(implementation, claims) do
      {:ok, implementation}
    else
      {:claims, nil} -> {:error, :unauthorized}
      {:can, false} -> {:error, :forbidden}
      {:error, :implementation, changeset, _} -> {:error, changeset}
    end
  end

  def deprecate_implementation(_parent, %{id: id}, resolution) do
    implementation = Implementations.get_implementation!(id)

    with {:claims, %{} = claims} <- {:claims, claims(resolution)},
         {:can, true} <- {:can, can?(claims, deprecate(implementation))},
         {:ok, %{implementation: implementation}} <-
           Workflow.deprecate_implementation(implementation, claims) do
      {:ok, implementation}
    else
      {:claims, nil} -> {:error, :unauthorized}
      {:can, false} -> {:error, :forbidden}
      {:error, :implementation, changeset, _} -> {:error, changeset}
    end
  end

  defp claims(%{context: %{claims: claims}}), do: claims
  defp claims(_), do: nil
end
