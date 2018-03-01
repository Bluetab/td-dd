defmodule DataQualityWeb.SwaggerDefinitions do
  @moduledoc """
   Swagger definitions used by controllers
  """
  import PhoenixSwagger

  def quality_control_definitions do
    %{
      QualityControl: swagger_schema do
        title "Quality Control"
        description "Quality Control entity"
        properties do
          id :integer, "unique identifier", required: true
          business_concept_id :string, "business concept id", required: true
          description :string, "description", required: true
          goal :integer, "goal percentage (1-100)"
          minimum :integer, "minimum goal (1-100)"
          name :string, "quality control name"
          population :string, "population target description"
          priority :string, "Priority (Medium,...)"
          type :string, "type: (Generic, ...)"
          weight :integer, "weight"
          status :string, "status (Default: defined)" #, default: "defined"
          version :integer, "version number"
          updated_by :string, "updated by user_name"
        end
      end,
      QualityControlCreateProps: swagger_schema do
        properties do
          type :string, "type: (Generic, ...)"
          business_concept_id :string, "business concept id", required: true
          name :string, "quality control name"
          description :string, "description", required: true
          weight :integer, "weight"
          priority :string, "Priority (Medium,...)"
          population :string, "population target description"
          goal :integer, "goal percentage (1-100)"
          minimum :integer, "minimum goal (1-100)"
        end
      end,
      QualityControlCreate: swagger_schema do
        properties do
          quality_control Schema.ref(:QualityControlCreateProps)
        end
      end,
      QualityControlUpdate: swagger_schema do
        properties do
          quality_control Schema.ref(:QualityControlCreateProps)
        end
      end,
      QualityControls: swagger_schema do
        title "Quality Controls"
        description "A collection of Quality Controls"
        type :array
        items Schema.ref(:QualityControl)
      end,
      QualityControlResponse: swagger_schema do
        properties do
          data Schema.ref(:QualityControl)
        end
      end,
      QualityControlsResponse: swagger_schema do
        properties do
          data Schema.ref(:QualityControls)
        end
      end

    }
  end
end
