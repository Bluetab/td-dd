defmodule TdDdWeb.Schema.Executions do
  @moduledoc """
  Absinthe schema definitions for quality executions and related entities.
  """

  use Absinthe.Schema.Notation

  import Absinthe.Resolution.Helpers, only: [dataloader: 1, dataloader: 3]

  object :execution_groups_connection do
    field :total_count, non_null(:integer)
    field :page, list_of(:execution_group)
    field :page_info, :page_info
  end

  object :executions_connection do
    field :total_count, non_null(:integer)
    field :page, list_of(:execution)
    field :page_info, :page_info
  end

  object :execution_group do
    field :id, non_null(:id)
    field :df_content, :json
    field :executions, list_of(:execution), resolve: dataloader(TdDq.Executions)
    field :implementations, list_of(:implementation), resolve: dataloader(TdDq.Executions)
    field :inserted_at, :datetime
    field :status_counts, :json, resolve: dataloader(TdDq.Executions.KV)
  end

  object :execution do
    field :id, non_null(:id)
    field :implementation, :implementation, resolve: dataloader(TdDq.Executions)
    field :quality_events, list_of(:quality_event), resolve: dataloader(TdDq.Executions)
    field :result, :implementation_result, resolve: dataloader(TdDq.Executions)
    field :rule, :rule, resolve: dataloader(TdDq.Executions)
    field :inserted_at, :datetime
    field :updated_at, :datetime

    field :latest_event, :quality_event,
      resolve:
        dataloader(TdDq.Executions, :quality_events,
          args: %{latest: true},
          callback: fn
            [e], _, _ -> {:ok, e}
            [], _, _ -> {:ok, nil}
            nil, _, _ -> {:ok, nil}
          end
        )
  end
end
