defmodule TdCx.K8s.LauncherTest do
  use ExUnit.Case

  alias K8s.Client.DynamicHTTPProvider
  alias TdCx.K8s.Launcher

  defmodule K8sMock do
    import TdCx.K8s.Factory

    def request(
          :get,
          "https://k8smock/apis/batch/v1beta1/namespaces/default/cronjobs",
          _,
          _,
          opts
        ) do
      assert Keyword.get(opts, :params) == %{
               labelSelector:
                 "truedat.io/connector-engine=connector-type,truedat.io/connector-type=job-type,truedat.io/launch-type=manual"
             }

      body =
        :list
        |> build(%{"items" => [build(:cron_job)]})
        |> Jason.encode!()

      {:ok, %HTTPoison.Response{status_code: 200, body: body}}
    end

    def request(:get, "https://k8smock/apis/batch/v1/namespaces/default/jobs", _, _, opts) do
      assert Keyword.get(opts, :params) == %{labelSelector: "job-name=job_id"}

      body =
        :list
        |> build(%{"items" => []})
        |> Jason.encode!()

      {:ok, %HTTPoison.Response{status_code: 200, body: body}}
    end

    def request(:post, "https://k8smock/apis/batch/v1/namespaces/default/jobs", body, _, _) do
      {:ok, %HTTPoison.Response{status_code: 201, body: body}}
    end
  end

  setup do
    {:ok, pid} = start_supervised({TdCx.K8s, Application.get_env(:td_cx, TdCx.K8s, [])})
    {:ok, _} = start_supervised(DynamicHTTPProvider)
    DynamicHTTPProvider.register(pid, __MODULE__.K8sMock)
    :ok
  end

  describe "launch/1" do
    test "creates a job from a cronjob" do
      source = %{type: "connector-type", external_id: "source_id"}
      job = %TdCx.Jobs.Job{source: source, type: "job-type", external_id: "job_id"}
      assert {:ok, k8s_job} = Launcher.launch(job)

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
               "spec" => %{
                 "template" => %{
                   "metadata" => %{
                     "labels" => ^expected_labels
                   },
                   "spec" => %{
                     "containers" => [
                       %{
                         "args" => ^expected_args,
                         "image" => "library/alpine:latest",
                         "name" => "container-name"
                       }
                     ]
                   }
                 }
               }
             } = k8s_job
    end
  end
end
