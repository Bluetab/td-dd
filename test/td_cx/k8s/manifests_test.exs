defmodule TdCx.K8s.ManifestsTest do
  use ExUnit.Case

  alias TdCx.K8s.Manifests

  setup do
    spec = %{
      "template" => %{
        "spec" => %{
          "containers" => [
            %{
              "envFrom" => [
                %{"configMapRef" => %{"name" => "someConfigMap"}},
                %{"secretRef" => %{"name" => "someSecret"}}
              ],
              "name" => "container-name"
            }
          ]
        }
      }
    }

    labels = %{
      "app.kubernetes.io/component" => "connector",
      "app.kubernetes.io/instance" => "td-connector-glue-athena",
      "app.kubernetes.io/name" => "td-connector-glue-athena",
      "app.kubernetes.io/part-of" => "truedat",
      "app.kubernetes.io/version" => "1.2.3",
      "truedat.io/connector-engine" => "Glue-Athena",
      "truedat.io/connector-type" => "Metadata",
      "truedat.io/launch-type" => "manual"
    }

    [spec: spec, labels: labels]
  end

  describe "job/4" do
    test "configures job manifest from cronjob spec and labels", %{spec: in_spec, labels: labels} do
      out_spec = Manifests.job("job_id", "source_id", in_spec, labels)

      expected_labels = %{
        "job-name" => "job_id",
        "truedat.io/connector-engine" => "Glue-Athena",
        "truedat.io/connector-type" => "Metadata",
        "truedat.io/launch-type" => "manual"
      }

      expected_args = ["job_id", "source_id"]

      assert %{
               "apiVersion" => "batch/v1",
               "kind" => "Job",
               "metadata" => %{
                 "labels" => ^expected_labels,
                 "name" => "job_id",
                 "namespace" => "default"
               },
               "spec" => %{"template" => template}
             } = out_spec

      assert %{
               "metadata" => %{"labels" => ^expected_labels},
               "spec" => %{
                 "containers" => [
                   %{
                     "args" => ^expected_args,
                     "envFrom" => _,
                     "name" => "container-name"
                   }
                 ]
               }
             } = template
    end
  end
end
