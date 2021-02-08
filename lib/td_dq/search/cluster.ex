defmodule TdDq.Search.Cluster do
  @moduledoc "Elasticsearch cluster configuration for TdDq"

  use Elasticsearch.Cluster, otp_app: :td_dq
end
