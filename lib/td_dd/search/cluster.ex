defmodule TdDd.Search.Cluster do
  @moduledoc "Elasticsearch cluster configuration for TdDd"

  use Elasticsearch.Cluster, otp_app: :td_dd

  def init(config) do
    indexes =
      config
      |> Map.get(:indexes)
      |> Enum.map(&prepend/1)
      |> Map.new()

    {:ok, %{config | indexes: indexes}}
  end

  defp prepend({index, %{settings: settings} = config}) do
    settings = Path.join(Application.app_dir(:td_dd), settings)
    {index, Map.put(config, :settings, settings)}
  end
end
