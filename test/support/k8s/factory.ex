defmodule TdCx.K8s.Factory do
  @moduledoc """
  ExMachine Factory for K8s resources
  """

  use ExMachina

  def labels_factory do
    %{
      "app.kubernetes.io/component" => "connector",
      "app.kubernetes.io/instance" => "td-connector-glue-athena",
      "app.kubernetes.io/name" => "td-connector-glue-athena",
      "app.kubernetes.io/part-of" => "truedat",
      "app.kubernetes.io/version" => "4.8.0",
      "truedat.io/connector-engine" => "Glue-Athena",
      "truedat.io/connector-type" => "Metadata",
      "truedat.io/launch-type" => "manual"
    }
  end

  def metadata_factory do
    %{
      "labels" => labels_factory(),
      "name" => "td-connector-glue-athena",
      "namespace" => "default",
      "resourceVersion" => "133349521",
      "selfLink" => "/apis/batch/v1beta1/namespaces/default/cronjobs/td-connector-glue-athena",
      "uid" => "1705429f-0989-11eb-bc55-0ae11f8863bb"
    }
  end

  def container_factory do
    %{"image" => "library/alpine:latest", "name" => "container-name"}
  end

  def pod_spec_factory do
    %{"containers" => [container_factory()]}
  end

  def pod_template_spec_factory do
    %{"metadata" => %{"creationTimestamp" => nil}, "spec" => pod_spec_factory()}
  end

  def job_spec_factory do
    %{"template" => pod_template_spec_factory()}
  end

  def job_template_factory do
    %{"metadata" => %{"creationTimestamp" => nil}, "spec" => job_spec_factory()}
  end

  def cron_job_spec_factory do
    %{"jobTemplate" => job_template_factory(), "schedule" => "@daily"}
  end

  def cron_job_factory do
    %{
      "apiVersion" => "batch/v1beta1",
      "kind" => "CronJob",
      "metadata" => metadata_factory(),
      "spec" => cron_job_spec_factory(),
      "status" => %{"lastScheduleTime" => "2020-11-25T10:00:00Z"}
    }
  end

  def job_factory do
    %{
      "apiVersion" => "batch/v1",
      "kind" => "Job",
      "metadata" => metadata_factory(),
      "spec" => job_spec_factory()
    }
  end

  def list_factory do
    %{
      "apiVersion" => "v1",
      "kind" => "List",
      "metadata" => %{"resourceVersion" => "", "selfLink" => ""},
      "items" => []
    }
  end
end
