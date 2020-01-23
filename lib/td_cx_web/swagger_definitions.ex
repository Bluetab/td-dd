
defmodule TdCxWeb.SwaggerDefinitions do
  @moduledoc false
  import PhoenixSwagger

  def source_definitions do
    %{
      CreateSource:
        swagger_schema do
          properties do
            source(
              Schema.new do
                properties do
                  external_id(:string, "External id of the source",
                    required: true
                  )

                  type(:string, "Source type that matches with a template in scope cx",
                    required: true
                  )

                  config(:object, "Source configuration")
                end
              end
            )
          end
        end,
      UpdateSource:
        swagger_schema do
          properties do
            source(
              Schema.new do
                properties do
                  config(:object, "Source configuration")
                end
              end
            )
          end
        end,
      Sources:
        swagger_schema do
          title("Sources")
          description("A collection of sources")
          type(:array)
          items(Schema.ref(:Source))
        end,
      Source:
        swagger_schema do
          title("Source")
          description("Representation of a source")

          properties do
            id(:integer, "Source Id", required: true)
            type(:string, "Source type that matches with a template in scope cx", required: true)
            config(:object, "Source configuration")
        end
        end,
        SourceResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:Source))
          end
        end,
        SourcesResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:Sources))
          end
        end,
    }
  end
end
