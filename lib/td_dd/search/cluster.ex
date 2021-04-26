defmodule TdDd.Search.Cluster do
  @moduledoc "Elasticsearch cluster configuration for TdDd"

  use Elasticsearch.Cluster, otp_app: :td_dd

  @impl GenServer
  def init(%{aliases: aliases, indexes: indexes, default_settings: defaults} = config) do
    indexes =
      Enum.reduce(aliases, %{}, fn
        {index, alias_name}, acc ->
          with %{settings: settings} = config <- Map.fetch!(indexes, index),
               %{} = config <- Map.put(config, :settings, Map.merge(settings, defaults)) do
            Map.put(acc, String.to_atom(alias_name), config)
          else
            _ -> acc
          end
      end)

    {:ok, %{config | indexes: indexes}}
  end

  @spec alias_name(atom) :: binary
  def alias_name(name) do
    __MODULE__
    |> Config.get()
    |> Map.get(:aliases)
    |> Map.get(name)
  end

  def setting(index_name, setting_name \\ :settings) do
    with %{aliases: aliases, indexes: indexes} <- Config.get(__MODULE__),
         alias_name <- Map.fetch!(aliases, index_name),
         index_config <- Map.fetch!(indexes, String.to_existing_atom(alias_name)) do
      Map.get(index_config, setting_name)
    end
  end
end
