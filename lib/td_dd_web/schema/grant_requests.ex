defmodule TdDdWeb.Schema.GrantRequests do
  @moduledoc """
  Absinthe schema definitions for Grant Requests
  """

  use Absinthe.Schema.Notation

  alias TdDdWeb.Resolvers

  object :grant_request_queries do
    @desc "Get grant request with status pending approved or processed by data_structure_id for active user"
    field :latest_grant_request, :grant_request do
      arg(:data_structure_id, non_null(:id))
      resolve(&Resolvers.GrantRequests.latest_grant_request/3)
    end
  end

  object :grant_request do
    field :id, non_null(:id)
    field :filters, :json
    field :metadata, :json
    field :group, :grant_request_group, resolve: &Resolvers.GrantRequests.group/3
    field :status, :grant_request_status, resolve: &Resolvers.GrantRequests.status/3
    field :data_structure_id, non_null(:id)
    field :domain_ids, list_of(:id)
    field :inserted_at, :datetime
  end

  object :grant_request_group do
    field :id, :id
    field :type, :string
    field :modification_grant_id, :id
    field :grant, :grant, resolve: &Resolvers.GrantRequests.grant/3
  end

  object :grant_request_status do
    field :id, :id
    field :status, :string
    field :reason, :string
  end
end
