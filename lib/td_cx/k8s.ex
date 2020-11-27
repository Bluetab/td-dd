defmodule TdCx.K8s do
  @moduledoc """
  Kubernetes client used to query and launch connector jobs.
  """

  use GenServer

  alias K8s.Client
  alias K8s.Conn
  alias K8s.Operation
  alias K8s.Selector

  require Logger

  @doc """
  Start the `GenServer` process.

  ## Options

    * `:namepace` - Kubernetes namespace

  """
  @spec start_link(keyword()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(config \\ []) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @doc """
  List Job objects.
  """
  @spec list_jobs(keyword()) :: {:error, any} | {:ok, list(map())}
  def list_jobs(opts \\ []) do
    list("batch/v1", "Job", opts)
  end

  @doc """
  List CronJob objects.
  """
  @spec list_cronjobs(keyword()) :: {:error, any} | {:ok, list(map())}
  def list_cronjobs(opts \\ []) do
    list("batch/v1beta1", "CronJob", opts)
  end

  @doc """
  Get the Job with the specified name.
  """
  @spec get_job(binary(), keyword()) :: {:error, any} | {:ok, map()}
  def get_job(name, opts \\ []) do
    get("batch/v1", "Job", Keyword.put(opts, :name, name))
  end

  @doc """
  List Pods.
  """
  @spec list_pods(keyword()) :: {:error, any} | {:ok, list(map())}
  def list_pods(opts \\ []) do
    list("v1", "Pod", opts)
  end

  @doc """
  List Events.
  """
  @spec list_events(keyword()) :: {:error, any} | {:ok, list(map())}
  def list_events(opts \\ []) do
    list("v1", "Event", opts)
  end

  @doc """
  Get the logs of a Pod with a specified name.
  """
  @spec logs(binary(), keyword()) :: {:error, any} | {:ok, binary()}
  def logs(name, opts \\ []) do
    get("v1", "pods/log", Keyword.put(opts, :name, name))
  end

  @doc """
  Create a Job.
  """
  @spec create_job(map()) :: {:error, any} | {:ok, map()}
  def create_job(job) do
    GenServer.call(__MODULE__, {:create, job})
  end

  @doc """
  Launch a Job.
  """
  @spec launch(struct()) :: :ok
  def launch(job) do
    GenServer.cast(__MODULE__, {:launch, job})
  end

  @doc """
  Delete a Job.
  """
  @spec delete_job(binary(), keyword()) :: {:error, any} | {:ok, map}
  def delete_job(name, opts \\ []) do
    delete("batch/v1", "Job", Keyword.put(opts, :name, name))
  end

  @spec list(binary(), binary(), keyword()) :: {:error, any} | {:ok, list(map())}
  defp list(api_version, kind, opts) do
    GenServer.call(__MODULE__, {:list, api_version, kind, opts})
  end

  @spec get(binary(), binary(), keyword()) :: {:error, any} | {:ok, list(map())}
  defp get(api_version, kind, opts) do
    GenServer.call(__MODULE__, {:get, api_version, kind, opts})
  end

  @spec delete(binary(), binary(), keyword()) :: {:error, any} | {:ok, list(map())}
  defp delete(api_version, kind, opts) do
    GenServer.call(__MODULE__, {:delete, api_version, kind, opts})
  end

  @impl true
  @spec init(any) :: {:ok, %{opts: keyword()}}
  def init(config) do
    {:ok, %{opts: config}}
  end

  @impl true
  def handle_call({:list, api_version, kind, opts}, _from, %{conn: conn} = state) do
    {list_opts, select_opts} = split_opts(opts, state, [:namespace])

    reply =
      select_opts
      |> Enum.reduce(Client.list(api_version, kind, list_opts), fn
        {:job_name, job_name}, op ->
          Selector.label(op, {"job-name", job_name})

        {:connector, connector}, op ->
          Selector.label(op, {"truedat.io/connector-engine", connector})

        {:job_type, job_type}, op ->
          Selector.label(op, {"truedat.io/connector-type", job_type})

        {:launch_type, launch_type}, op ->
          Selector.label(op, {"truedat.io/launch-type", launch_type})
      end)
      |> Client.run(conn)
      |> unwrap()

    {:reply, reply, state}
  end

  @impl true
  def handle_call({:get, api_version, kind, opts}, _from, %{conn: conn} = state) do
    {query_opts, other_opts} = split_opts(opts, state)

    res =
      other_opts
      |> Enum.reduce(Client.get(api_version, kind, query_opts), fn
        {:timestamps, true}, op -> Operation.put_query_param(op, :timestamps, "true")
      end)
      |> Client.run(conn)

    {:reply, res, state}
  end

  @impl true
  def handle_call({:delete, api_version, kind, opts}, _from, %{conn: conn} = state) do
    {delete_opts, _} = split_opts(opts, state)

    res =
      api_version
      |> Client.delete(kind, delete_opts)
      |> Client.run(conn)

    {:reply, res, state}
  end

  @impl true
  def handle_call({:create, resource}, _from, %{conn: conn} = state) do
    res =
      resource
      |> Client.create()
      |> Client.run(conn)

    {:reply, res, state}
  end

  @impl true
  def handle_call(request, from, %{} = state) when not is_map_key(state, :conn) do
    # Put conn into the state if it's not present
    case Conn.lookup(:default) do
      {:ok, conn} ->
        state = Map.put(state, :conn, conn)
        handle_call(request, from, state)

      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_cast({:launch, job}, state) do
    alias TdCx.K8s.Launcher

    Task.Supervisor.async_nolink(TdCx.TaskSupervisor, fn ->
      Launcher.launch(job)
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, result}, state) do
    unless result == :normal do
      Logger.warn("#{inspect(ref)} failed")
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({ref, _res}, state) when is_reference(ref) do
    {:noreply, state}
  end

  defp split_opts(opts, %{opts: default_opts} = _state, keys \\ [:namespace, :name]) do
    {_query_opts, _other_opts} =
      default_opts
      |> Keyword.merge(opts)
      |> Keyword.split(keys)
  end

  defp unwrap({:ok, %{"items" => items}}), do: {:ok, items}
  defp unwrap(other), do: other
end
