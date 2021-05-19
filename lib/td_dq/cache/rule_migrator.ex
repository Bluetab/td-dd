defmodule TdDq.Cache.RuleMigrator do
    @moduledoc """
    GenServer migrate rules with data from cache.
    """
  
    use GenServer
  
    alias TdCache.Redix
    alias TdCache.ConceptCache
    alias TdDq.Auth.Claims
    alias TdDq.Rules
  
    require Logger
    
    ## Client API
  
    def start_link(config \\ []) do
      GenServer.start_link(__MODULE__, config, name: __MODULE__)
    end
  
    ## GenServer Callbacks
  
    @impl true
    def init(state) do
      name = String.replace_prefix("#{__MODULE__}", "Elixir.", "")
      Logger.info("Running #{name}")
  
      unless Application.get_env(:td_dd, :env) == :test do
        Process.send_after(self(), :migrate_domains, 0)
      end
  
      {:ok, state}
    end
  
    @impl true
    def handle_info(:migrate_domains, state) do
      if acquire_lock?("TdDq.Cache.RuleLoader:TD-3446") do
        {oks, errors} =
          Rules.list_rules()
          |> Enum.filter(& &1.business_concept_id)
          |> Enum.map(&fetch_domain/1)
          |> Enum.filter(&elem(&1, 1))
          |> Enum.map(&update_rule/1)
          |> Enum.split_with(&(elem(&1, 0) == :ok))
  
        case errors do
          [] ->
            Logger.info("RuleLoader: Linked #{Enum.count(oks)} rules to domain id")
  
          _ ->
            ids =
              errors
              |> Enum.map(&elem(&1, 2))
              |> Enum.map(&get_in(&1, [:data, :id]))
              |> Enum.join(",")
  
            Logger.error("RuleLoader: Error while linking the following ids to a domain id: #{ids}")
        end
      end
  
      {:noreply, state}
    end
  
    ## Private functions
  
    defp acquire_lock?(key) do
      Redix.command!(["SET", key, node(), "NX"])
    end
  
    defp fetch_domain(%{business_concept_id: id} = rule) do
      case ConceptCache.get(id) do
        {:ok, %{domain_id: domain_id}} -> {rule, domain_id}
        _ -> {rule, nil}
      end
    end
  
    defp update_rule({rule, domain_id}) do
      Rules.update_rule(rule, %{domain_id: domain_id}, %Claims{
        user_id: 0,
        user_name: "system"
      })
    end
  end
  