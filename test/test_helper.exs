# FIXME ensure it's not necessary
# {:ok, _} = Application.ensure_all_started(:ex_machina)
# Mox.defmock(ElasticsearchMock, for: Elasticsearch.API)
# Mox.defmock(MockClusterHandler, for: TdCluster.ClusterHandler)
TdCache.Redix.del!()
ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(TdDd.Repo, :manual)
