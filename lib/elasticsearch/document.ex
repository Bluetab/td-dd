defimpl Elasticsearch.Document, for: Integer do
  @impl Elasticsearch.Document
  def id(value), do: value

  @impl Elasticsearch.Document
  def routing(_), do: false

  @impl Elasticsearch.Document
  def encode(_), do: raise("encode not implemented for Integer")
end
