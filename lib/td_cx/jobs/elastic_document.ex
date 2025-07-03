defmodule TdCx.Jobs.ElasticDocument do
  @moduledoc """
  Elasticsearch mapping and aggregation
  definition for Jobs
  """

  alias Elasticsearch.Document
  alias TdCore.Search.Cluster
  alias TdCore.Search.ElasticDocument
  alias TdCore.Search.ElasticDocumentProtocol
  alias TdCx.Jobs
  alias TdCx.Jobs.Job

  defimpl Document, for: Job do
    use ElasticDocument

    @default_status "PENDING"
    @max_message_length 1_000

    @impl Elasticsearch.Document
    def id(%Job{id: id}), do: id

    @impl Elasticsearch.Document
    def routing(_), do: false

    @impl Elasticsearch.Document
    def encode(
          %Job{source: source, events: events, inserted_at: inserted_at, updated_at: updated_at} =
            job
        ) do
      source = Map.take(source, [:external_id, :type])
      type = Map.get(job, :type) || ""

      job
      |> Map.take([:id, :external_id, :source_id])
      |> Map.put(:type, type)
      |> Map.put(:source, source)
      |> Map.merge(Jobs.metrics(events, max_length: @max_message_length))
      |> Map.put_new(:start_date, inserted_at)
      |> Map.put_new(:end_date, updated_at)
      |> Map.put_new(:status, @default_status)
    end
  end

  defimpl ElasticDocumentProtocol, for: Job do
    use ElasticDocument

    @search_fields ~w(external_id source.external_id message)

    def mappings(_) do
      mapping_type = %{
        id: %{type: "long"},
        source_id: %{type: "long"},
        external_id: %{
          type: "text",
          fields: Map.merge(%{raw: %{type: "keyword", normalizer: "sortable"}}, @exact)
        },
        source: %{
          properties: %{
            external_id: %{type: "text", fields: @raw_sort},
            type: %{type: "text", fields: @raw_sort}
          }
        },
        start_date: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
        end_date: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
        status: %{type: "text", fields: @raw_sort},
        type: %{type: "text", fields: @raw_sort},
        message: %{type: "text", fields: @exact}
      }

      settings = :jobs |> Cluster.setting() |> apply_lang_settings()

      %{mappings: %{properties: mapping_type}, settings: settings}
    end

    def aggregations(_) do
      %{
        "source_external_id" => %{
          terms: %{
            field: "source.external_id.raw",
            size: Cluster.get_size_field("source_external_id")
          }
        },
        "source_type" => %{
          terms: %{field: "source.type.raw", size: Cluster.get_size_field("source_type")}
        },
        "status" => %{terms: %{field: "status.raw", size: Cluster.get_size_field("status")}},
        "type" => %{terms: %{field: "type.raw", size: Cluster.get_size_field("type")}}
      }
    end

    def query_data(_) do
      %{
        fields: @search_fields,
        simple_search_fields: @search_fields,
        aggs: aggregations(%Job{})
      }
    end
  end
end
