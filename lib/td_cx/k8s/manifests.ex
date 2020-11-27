defmodule TdCx.K8s.Manifests do
  @moduledoc """
  Utility functions to manage kubernetes manifests for launching connector jobs.
  """

  def job(external_id, source_external_id, %{"template" => template} = spec, labels) do
    labels =
      labels
      |> Enum.filter(fn {k, _} -> String.starts_with?(k, "truedat.io/") end)
      |> Map.new()
      |> Map.put("job-name", external_id)
      |> Map.put("truedat.io/launch-type", "manual")

    template =
      template
      |> merge_labels(labels)
      |> put_args([external_id, source_external_id])

    %{
      "apiVersion" => "batch/v1",
      "kind" => "Job",
      "metadata" => %{
        "labels" => labels,
        "name" => external_id,
        "namespace" => job_namespace()
      },
      "spec" => Map.put(spec, "template", template)
    }
  end

  def merge_labels(%{} = template, labels) do
    metadata =
      template
      |> Map.get("metadata", %{})
      |> Map.merge(%{"labels" => labels}, fn _k, v1, v2 -> Map.merge(v1, v2) end)

    Map.put(template, "metadata", metadata)
  end

  def put_args(%{"spec" => pod_spec} = template, args) do
    %{template | "spec" => put_args(pod_spec, args)}
  end

  def put_args(%{"containers" => containers} = pod_spec, args) do
    %{pod_spec | "containers" => Enum.map(containers, &Map.put(&1, "args", args))}
  end

  defp job_namespace do
    :td_cx
    |> Application.get_env(:k8s, [])
    |> Keyword.get(:namespace, "default")
  end
end
