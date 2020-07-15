defmodule TdDd.DataStructures.DataStructureTypeMigrator do
  @moduledoc """
  GenServer to create Data Structure Type - template associations
  """

  use GenServer

  import Ecto.Query

  alias TdCache.Redix
  alias TdCache.TemplateCache
  alias TdDd.DataStructures.DataStructureType
  alias TdDd.Repo

  require Logger

  @data_structure_types_migrator_key "TdDd.DataStructures.Migrations:TD-2774"

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

    unless Application.get_env(:td_dd, :env) == :test do
      Process.send_after(self(), :migrate_data_structure_types, 0)
    end

    {:ok, state}
  end

  @impl true
  def handle_info(:migrate_data_structure_types, state) do
    if Redix.exists?(@data_structure_types_migrator_key) == false do
      # --- templates ----
      {:ok, templates} = TemplateCache.list_by_scope("dd")

      # ---- structure versions types
      query = from(ds in "data_structure_versions")

      structure_version_types =
        query
        |> distinct(true)
        |> select([ds], ds.type)
        |> where([ds], is_nil(ds.deleted_at))
        |> Repo.all()

      Repo.transaction(fn ->
        templates
        |> Enum.each(&migrate_data_structure_type(&1, structure_version_types))
      end)

      Redix.command!([
        "SET",
        @data_structure_types_migrator_key,
        "#{DateTime.utc_now()}"
      ])
    end

    Process.send_after(self(), :migrate_data_structure_types, 60_000)

    {:noreply, state}
  end

  defp migrate_data_structure_type(
         %{id: template_id, name: template_name},
         structure_version_types
       ) do
    if Enum.find(structure_version_types, &(&1 == template_name)) do
      Repo.insert!(%DataStructureType{
        structure_type: template_name,
        template_id: template_id
      })
    end
  end

  @impl GenServer
  def handle_call(:ping, _from, state) do
    {:reply, :pong, state}
  end
end
