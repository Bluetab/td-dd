defmodule TdDdWeb.Schema.Tasks do
  @moduledoc """
  Absinthe schema definitions for indexing stats.
  """

  use Absinthe.Schema.Notation

  alias TdDdWeb.Resolvers

  object :task_query do
    @desc "Get a list of tasks"
    field :tasks, list_of(:task) do
      resolve(&Resolvers.Tasks.tasks/3)
    end

    @desc "Get a task"
    field :task, :task do
      arg(:id, :string)
      resolve(&Resolvers.Tasks.task/3)
    end
  end

  object :task do
    field :id, :string
    field :index, :string
    field :status, :string
    field :started_at, :datetime
    field :last_message_at, :datetime
    field :count, :integer
    field :processed, :integer
    field :memory_trace, :json
    field :elapsed, :integer
  end
end
