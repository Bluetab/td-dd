defmodule TdDdWeb.Schema.Remediations do
  @moduledoc """
  Absinthe schema definitions for remediations and related entities.
  """

  use Absinthe.Schema.Notation

  alias TdDdWeb.Resolvers

  object :remediation_queries do
    @desc "Get a remediation"
    field :remediation, :remediation do
      arg(:id, :id)
      resolve(&Resolvers.Remediations.remediation/3)
    end

    @desc "Get remediations"
    field :remediations_connection, :remediations_connection do
      arg(:first, :integer)
      arg(:last, :integer)
      arg(:after, :cursor)
      arg(:before, :cursor)
      arg(:filters, :remediation_filter_input)
      resolve(&Resolvers.Remediations.remediations_connection/3)
    end
  end

  object :remediations_connection do
    field(:total_count, non_null(:integer))
    field(:page, list_of(:remediation))
    field(:page_info, :page_info)
  end

  object :remediation do
    field(:id, :id)
    field(:df_name, :string)
    field(:df_content, :json)
    field(:inserted_at, :datetime)
    field(:updated_at, :datetime)
  end

  input_object :remediation_filter_input do
    field(:inserted_since, :datetime)
    field(:updated_since, :datetime)
  end
end
