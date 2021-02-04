defmodule TdDd.Search.Cluster do
  @moduledoc "Elasticsearch cluster configuration for TdDd"

  use Elasticsearch.Cluster, otp_app: :td_dd
end
