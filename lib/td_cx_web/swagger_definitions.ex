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
                  external_id(:string, "External id of the source", required: true)

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
        end
    }
  end

  def configuration_definitions do
    %{
      CreateConfiguration:
        swagger_schema do
          properties do
            configuration(
              Schema.new do
                properties do
                  external_id(:string, "External id of the configuration", required: true)

                  type(:string, "Configuration type that matches with a template in scope ca",
                    required: true
                  )

                  content(:object, "Configuration dynamic content")
                end
              end
            )
          end
        end,
      UpdateConfiguration:
        swagger_schema do
          properties do
            configuration(
              Schema.new do
                properties do
                  content(:object, "Configuration dynamic content")
                end
              end
            )
          end
        end,
      Configurations:
        swagger_schema do
          title("Configurations")
          description("A collection of configurations")
          type(:array)
          items(Schema.ref(:Configuration))
        end,
      Configuration:
        swagger_schema do
          title("Configuration")
          description("Representation of a configuration")

          properties do
            id(:integer, "Configuration Id", required: true)

            type(:string, "Configuration type that matches with a template in scope ca",
              required: true
            )

            content(:object, "Configuration dynamic content")
            secrets_key(:string, "Secrets Key")
          end
        end,
      ConfigurationResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:Configuration))
          end
        end,
      ConfigurationsResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:Configurations))
          end
        end
    }
  end

  def job_definitions do
    %{
      Jobs:
        swagger_schema do
          title("Jobs")
          description("A collection of jobs")
          type(:array)
          items(Schema.ref(:Job))
        end,
      Job:
        swagger_schema do
          title("Job")
          description("Representation of a job")

          properties do
            id(:integer, "Job Id", required: true)
            external_id(:string, "Job external id", required: true)
            source(:object, "Source of a job")
            start_date(:string, "Start date of a job")
            end_date(:string, "End date of a job")
            status(:string, "Job status")
            message(:string, "Last job message")
          end
        end,
      JobResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:Job))
          end
        end,
      JobsResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:Jobs))
          end
        end,
      JobFilterRequest:
        swagger_schema do
          properties do
            query(:string, "Query string", required: false)
            filters(:object, "Filters", required: false)
          end

          example(%{
            query: "searchterm",
            filters: %{
              status: ["init"]
            }
          })
        end
    }
  end

  def event_definitions do
    %{
      Events:
        swagger_schema do
          title("Events")
          description("A collection of events")
          type(:array)
          items(Schema.ref(:Event))
        end,
      Event:
        swagger_schema do
          title("Event")
          description("Representation of a event")

          properties do
            id(:integer, "Event Id", required: true)
            inserted_at(:string, "Event insertion date")
            type(:string, "Event type")
            message(:string, "Event message")
          end
        end,
      EventResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:Event))
          end
        end,
      EventsResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:Events))
          end
        end,
      CreateEvent:
        swagger_schema do
          properties do
            event(
              Schema.new do
                properties do
                  type(:string, "Event type")
                  message(:string, "Event message")
                end
              end
            )
          end
        end
    }
  end

  def filter_swagger_definitions do
    %{
      FilterResponse:
        swagger_schema do
          title("Filters")

          description(
            "An object whose keys are filter names and values are arrays of filterable values"
          )

          properties do
            data(:object, "Filter values", required: true)
          end

          example(%{
            data: %{
              status: ["init", "end"]
            }
          })
        end
    }
  end
end
