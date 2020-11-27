defmodule TdCx.K8sTest do
  use ExUnit.Case

  alias K8s.Client.DynamicHTTPProvider

  defmodule K8sMock do
    def request(method, url, body, _headers, opts) do
      body = response_body(method, url, opts, body)
      {:ok, %HTTPoison.Response{status_code: 200, body: body}}
    end

    defp response_body(method, url, opts, body) do
      params = Keyword.get(opts, :params)

      %{"method" => method, "url" => url, "params" => params, "body" => body}
      |> Enum.reject(fn {_, v} -> is_nil(v) end)
      |> Enum.reject(fn {_, v} -> v == "" end)
      |> Map.new()
      |> Jason.encode!()
    end
  end

  setup do
    {:ok, pid} = start_supervised({TdCx.K8s, Application.get_env(:td_cx, TdCx.K8s, [])})
    {:ok, _pid} = start_supervised(DynamicHTTPProvider)
    DynamicHTTPProvider.register(pid, __MODULE__.K8sMock)
    :ok
  end

  describe "list_events/1" do
    test "queries the default namespace" do
      assert {:ok, %{"url" => "https://k8smock/api/v1/namespaces/default/events"}} =
               TdCx.K8s.list_events()
    end

    test "queries a custom namespace" do
      assert {:ok, %{"url" => "https://k8smock/api/v1/namespaces/foo/events"}} =
               TdCx.K8s.list_events(namespace: "foo")
    end

    test "queries a all namespaces" do
      assert {:ok, %{"url" => "https://k8smock/api/v1/events"}} =
               TdCx.K8s.list_events(namespace: :all)
    end
  end

  describe "list_cronjobs/1" do
    test "queries the connector-engine selector label" do
      assert {:ok,
              %{
                "method" => "get",
                "url" => "https://k8smock/apis/batch/v1beta1/namespaces/default/cronjobs",
                "params" => %{"labelSelector" => "truedat.io/connector-engine=foo"}
              }} = TdCx.K8s.list_cronjobs(connector: "foo")
    end

    test "queries the connector-type selector label" do
      assert {:ok,
              %{
                "method" => "get",
                "url" => "https://k8smock/apis/batch/v1beta1/namespaces/default/cronjobs",
                "params" => %{"labelSelector" => "truedat.io/connector-type=foo"}
              }} = TdCx.K8s.list_cronjobs(job_type: "foo")
    end

    test "queries the launch-type selector label" do
      assert {:ok,
              %{
                "method" => "get",
                "url" => "https://k8smock/apis/batch/v1beta1/namespaces/default/cronjobs",
                "params" => %{"labelSelector" => "truedat.io/launch-type=foo"}
              }} = TdCx.K8s.list_cronjobs(launch_type: "foo")
    end
  end

  describe "list_jobs/1" do
    test "queries the job-name selector label" do
      assert {:ok,
              %{
                "method" => "get",
                "url" => "https://k8smock/apis/batch/v1/namespaces/default/jobs",
                "params" => %{"labelSelector" => "job-name=foo"}
              }} = TdCx.K8s.list_jobs(job_name: "foo")
    end
  end

  describe "list_pods/1" do
    test "queries the job-name selector label" do
      assert {:ok,
              %{
                "method" => "get",
                "url" => "https://k8smock/api/v1/namespaces/default/pods",
                "params" => %{"labelSelector" => "job-name=foo"}
              }} = TdCx.K8s.list_pods(job_name: "foo")
    end
  end

  describe "get_job/1" do
    test "queries the job url" do
      assert {:ok,
              %{
                "method" => "get",
                "url" => "https://k8smock/apis/batch/v1/namespaces/default/jobs/foo"
              }} = TdCx.K8s.get_job("foo")
    end
  end

  describe "delete_job/1" do
    test "deletes the job url" do
      assert {:ok,
              %{
                "method" => "delete",
                "url" => "https://k8smock/apis/batch/v1/namespaces/default/jobs/foo"
              }} = TdCx.K8s.delete_job("foo")
    end
  end

  describe "logs/1" do
    test "queries the job log url" do
      assert {:ok,
              %{
                "method" => "get",
                "url" => "https://k8smock/api/v1/namespaces/default/pods/foo/log"
              }} = TdCx.K8s.logs("foo")
    end
  end

  describe "create_job/1" do
    test "posts to the jobs url" do
      job = %{
        "apiVersion" => "batch/v1",
        "kind" => "Job",
        "metadata" => %{"namespace" => "default", "name" => "test-job"}
      }

      assert {:ok,
              %{
                "method" => "post",
                "url" => "https://k8smock/apis/batch/v1/namespaces/default/jobs",
                "body" => body
              }} = TdCx.K8s.create_job(job)

      assert body == Jason.encode!(job)
    end
  end
end
