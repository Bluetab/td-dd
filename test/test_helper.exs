Mox.defmock(ElasticsearchMock, for: Elasticsearch.API)
ExUnit.start()
TdCache.Redix.del!()
Ecto.Adapters.SQL.Sandbox.mode(TdDd.Repo, :manual)
