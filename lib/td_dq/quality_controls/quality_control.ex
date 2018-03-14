defmodule TdDq.QualityControls.QualityControl do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias TdDq.QualityControls.QualityControl

  @statuses ["defined"]

  schema "quality_controls" do
    field :business_concept_id, :string
    field :description, :string
    field :goal, :integer
    field :minimum, :integer
    field :name, :string
    field :population, :string
    field :priority, :string
    field :type, :string
    field :type_params, :map
    field :weight, :integer
    field :status, :string, default: "defined"
    field :version, :integer, default: 1
    field :updated_by, :string

    timestamps()
  end

  @doc false
  def changeset(%QualityControl{} = quality_control, attrs) do
    quality_control
    |> cast(attrs, [:type, :business_concept_id, :name, :description, :weight, :priority, :population, :goal, :minimum, :status, :version, :updated_by])
    |> validate_required([:type, :business_concept_id, :name, :description, :weight, :priority, :population, :goal, :minimum, :status, :version, :updated_by])
  end

  def get_statuses do
    @statuses
  end

  def defined_status do
    "defined"
  end

end
