defmodule TdDq.Rules.Implementations.Migrator do
  @moduledoc """
  GenServer to put structures used in rule implementations in cache
  """

  use GenServer

  import Ecto.Query

  alias TdCache.Redix
  alias TdDq.Repo
  alias TdDq.Rules.Implementations.MigratorTypes

  require Logger

  @implementation_structures_cache_migration_key "TdDq.Implementations.Migrations:cache_structures"
  @implementation_structures_migration_key "TdDq.Implementations.Migrations:td-2210"
  @structure_parent_id_migration_key "TdDd.DataStructures.Migrations:td-2210"

  ## Client API

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def ping(timeout \\ 5000) do
    GenServer.call(__MODULE__, :ping, timeout)
  end

  ## GenServer Callbacks

  @impl GenServer
  def init(state) do
    name = String.replace_prefix("#{__MODULE__}", "Elixir.", "")
    Logger.info("Running #{name}")

    unless Application.get_env(:td_dq, :env) == :test do
      Process.send_after(self(), :migrate_implementations, 0)
    end

    {:ok, state}
  end

  @impl true
  def handle_info(:migrate_implementations, state) do
    if Redix.exists?(@implementation_structures_cache_migration_key) == true and
         Redix.exists?(@structure_parent_id_migration_key) == true and
         Redix.exists?(@implementation_structures_migration_key) == false do
      query = from(ri in "rule_implementations")

      query
      |> join(:inner, [ri, r], r in "rules", on: r.id == ri.rule_id)
      |> join(:inner, [_, r, rt], rt in "rule_types", on: rt.id == r.rule_type_id)
      |> select([ri, r, rt], %{
        id: ri.id,
        system_params: ri.system_params,
        rule_type_name: rt.name,
        rule_type_params: rt.params,
        rule_rule_type_params: r.type_params
      })
      |> Repo.all()
      |> Enum.each(&MigratorTypes.migrate_implementation/1)

      Redix.command!([
        "SET",
        @implementation_structures_migration_key,
        "#{DateTime.utc_now()}"
      ])
    end

    Process.send_after(self(), :migrate_implementations, 60_000)

    {:noreply, state}
  end

  @impl GenServer
  def handle_call(:ping, _from, state) do
    {:reply, :pong, state}
  end
end
