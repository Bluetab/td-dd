defmodule TdCx.Search.Cluster do
  @moduledoc "Elasticsearch cluster configuration for TdCx"

  use Elasticsearch.Cluster, otp_app: :td_cx

  require Logger

  def init(config) do
    config =
      case read_url() do
        nil -> config
        url -> Map.put(config, :url, url)
      end

    {:ok, config}
  end

  defp read_url do
    ["ES_URL", "ES_HOST", "ES_PORT"]
    |> Enum.map(&System.get_env/1)
    |> Enum.map(fn s -> if s == "", do: nil, else: s end)
    |> read_url()
  end

  defp read_url([nil, nil, nil]), do: nil

  defp read_url([nil, host, nil]) do
    Logger.warn("ES_HOST variable is deprecated, use ES_URL instead")
    parse_url(host)
  end

  defp read_url([nil, host, port]) do
    Logger.warn("ES_HOST variable is deprecated, use ES_URL instead")
    parse_url("#{host}:#{port}")
  end

  defp read_url([url, _, _]), do: parse_url(url)

  defp parse_url(url) do
    case String.split(url, "://", parts: 2) do
      ["http", _] -> url
      ["https", _] -> url
      _ -> parse_url("http://#{url}")
    end
  end
end
