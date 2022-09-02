defmodule TdDdWeb.Schema.Executions do
  @moduledoc """
  Absinthe schema definitions for quality executions and related entities.
  """

  use Absinthe.Schema.Notation

  import Absinthe.Resolution.Helpers, only: [dataloader: 1]

  object :execution_groups_connection do
    field :total_count, non_null(:integer)
    field :page, list_of(:execution_group)
    field :page_info, :page_info
  end

  object :page_info do
    field :end_cursor, :cursor
    field :start_cursor, :cursor
    field :has_next_page, non_null(:boolean)
    field :has_previous_page, non_null(:boolean)
  end

  object :execution_group do
    field :id, non_null(:id)
    field :df_content, :json
    field :executions, list_of(:execution), resolve: dataloader(TdDq.Executions)
    field :implementations, list_of(:implementation), resolve: dataloader(TdDq.Executions)
    field :inserted_at, :datetime
  end

  object :execution do
    field :id, non_null(:id)
    field :implementation, :implementation, resolve: dataloader(TdDq.Executions)
    field :quality_events, list_of(:quality_event), resolve: dataloader(TdDq.Executions)
    field :result, :implementation_result, resolve: dataloader(TdDq.Executions)
    field :rule, :rule, resolve: dataloader(TdDq.Executions)
    field :inserted_at, :datetime
    field :updated_at, :datetime
  end
end
