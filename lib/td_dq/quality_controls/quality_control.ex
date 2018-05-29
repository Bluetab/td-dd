defmodule TdDq.QualityControls.QualityControl do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias TdDq.QualityControls.QualityControl
  alias Poison, as: JSON

  @statuses ["defined"]

  schema "quality_controls" do
    field :business_concept_id, :string
    field :description, :string
    field :goal, :integer
    field :minimum, :integer
    field :name, :string
    field :population, :string
    field :priority, :string
    field :weight, :integer
    field :status, :string, default: "defined"
    field :version, :integer, default: 1
    field :updated_by, :integer

    timestamps()
  end

  @doc false
  def changeset(%QualityControl{} = quality_control, attrs) do
    quality_control
    |> cast(attrs, [:business_concept_id, :name, :description, :weight, :priority, :population, :goal, :minimum, :status, :version, :updated_by])
    |> validate_required([:business_concept_id, :name, :description, :weight, :priority, :population, :goal, :minimum, :status, :version, :updated_by])
  end

  def get_statuses do
    @statuses
  end

  def defined_status do
    "defined"
  end

  def get_quality_control_types do
    file_name = Application.get_env(:td_dq, :qc_types_file)
    file_path = Path.join(:code.priv_dir(:td_dq), file_name)
    file_path
    |> File.read!
    |> JSON.decode!
  end

end
