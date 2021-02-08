defmodule TdCx.Search.Cluster do
  @moduledoc "Elasticsearch cluster configuration for TdCx"

  use Elasticsearch.Cluster, otp_app: :td_cx
end
