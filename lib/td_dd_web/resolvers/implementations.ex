defmodule TdDdWeb.Resolvers.Implementations do
  @moduledoc """
  Absinthe resolvers for implementations
  """

  alias TdDd.Utils.ChangesetUtils
  alias TdDq.Events.QualityEvents
  alias TdDq.Implementations
  alias TdDq.Implementations.Workflow
  alias TdDq.Rules.RuleResults

  def implementation(_parent, %{id: id}, resolution) do
    with {:claims, %{} = claims} <- {:claims, claims(resolution)},
         implementation <- Implementations.get_implementation!(id),
         :ok <- Bodyguard.permit(Implementations, :view, claims, implementation) do
      {:ok, implementation}
    else
      {:claims, nil} -> {:error, :unauthorized}
      {:error, :forbidden} -> {:error, :forbidden}
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
         :ok <- Bodyguard.permit(Implementations, :submit, claims, implementation),
         {:ok, %{implementation: implementation}} <-
           Workflow.submit_implementation(implementation, claims) do
      {:ok, implementation}
    else
      {:claims, nil} -> {:error, :unauthorized}
      {:error, :forbidden} -> {:error, :forbidden}
      {:error, :implementation, changeset, _} -> {:error, changeset}
    end
  end

  def reject_implementation(_parent, %{id: id}, resolution) do
    implementation = Implementations.get_implementation!(id)

    with {:claims, %{} = claims} <- {:claims, claims(resolution)},
         :ok <- Bodyguard.permit(Implementations, :reject, claims, implementation),
         {:ok, %{implementation: implementation}} <-
           Workflow.reject_implementation(implementation, claims) do
      {:ok, implementation}
    else
      {:claims, nil} -> {:error, :unauthorized}
      {:error, :forbidden} -> {:error, :forbidden}
      {:error, :implementation, changeset, _} -> {:error, changeset}
    end
  end

  def publish_implementation(_parent, %{id: id}, resolution) do
    implementation = Implementations.get_implementation!(id)

    with {:claims, %{} = claims} <- {:claims, claims(resolution)},
         :ok <- Bodyguard.permit(Implementations, :publish, claims, implementation),
         {:ok, %{implementation: implementation}} <-
           Workflow.publish_implementation(implementation, claims) do
      {:ok, implementation}
    else
      {:claims, nil} -> {:error, :unauthorized}
      {:error, :forbidden} -> {:error, :forbidden}
      {:error, :implementation, changeset, _} -> {:error, changeset}
    end
  end

  def restore_implementation(_parent, %{id: id}, resolution) do
    implementation = Implementations.get_implementation!(id)

    with {:claims, %{} = claims} <- {:claims, claims(resolution)},
         :ok <- Bodyguard.permit(Implementations, :restore, claims, implementation),
         {:ok, %{implementation: implementation}} <-
           Workflow.restore_implementation(implementation, claims) do
      {:ok, implementation}
    else
      {:claims, nil} ->
        {:error, :unauthorized}

      {:error, :forbidden} ->
        {:error, :forbidden}

      {:error, :implementation, changeset, _} ->
        {:error, ChangesetUtils.error_message_list_on(changeset)}
    end
  end

  def deprecate_implementation(_parent, %{id: id}, resolution) do
    implementation = Implementations.get_implementation!(id)

    with {:claims, %{} = claims} <- {:claims, claims(resolution)},
         :ok <- Bodyguard.permit(Implementations, :deprecate, claims, implementation),
         {:ok, %{implementation: implementation}} <-
           Workflow.deprecate_implementation(implementation, claims) do
      {:ok, implementation}
    else
      {:claims, nil} -> {:error, :unauthorized}
      {:error, :forbidden} -> {:error, :forbidden}
      {:error, :implementation, changeset, _} -> {:error, changeset}
    end
  end

  defp claims(%{context: %{claims: claims}}), do: claims
  defp claims(_), do: nil
end
