defmodule TdDq.QualityControls.QualityControl do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias TdDq.QualityControls.QualityControl
  alias TdDq.QualityRules
  alias TdDq.QualityRules.QualityRule

  @statuses ["defined"]
  @datetime_format "%Y-%m-%d %H:%M:%S"
  @date_format "%Y-%m-%d"

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
    field :principle, :map
    field :type, :string
    field :type_params, :map
    has_many :quality_rules, QualityRule

    timestamps()
  end

  @doc false
  def changeset(%QualityControl{} = quality_control, attrs) do
    quality_control
    |> cast(attrs, [:business_concept_id,
                    :name,
                    :description,
                    :weight,
                    :priority,
                    :population,
                    :goal,
                    :minimum,
                    :status,
                    :version,
                    :updated_by,
                    :principle,
                    :type,
                    :type_params])
    |> validate_required([:business_concept_id, :name, :type])
    |> validate_type
  end

  def get_statuses do
    @statuses
  end

  def defined_status do
    "defined"
  end

  defp validate_type(changeset) do
    type_name = get_change(changeset, :type)
    if type_name == nil do
      changeset
    else
      type = QualityRules.get_quality_rule_type_by_name(type_name)
      case type do
        nil ->
          changeset
          |> add_error(:type, "Type #{inspect(type_name)} does not exist")
        type ->
          changeset
          |> validate_type_params(type)
      end
    end
  end

  defp validate_type_params(changeset, type) do
    type_params = get_change(changeset, :type_params)
    with {:ok, changeset} <- validata_params_length(changeset, type_params, type.params["type_params"]),
         {:ok, changeset} <- do_validate_params_keys(changeset, type_params, type.params["type_params"]) do
          changeset
    else
      {:error, error} -> changeset |> add_error(:type_params, error)
    end
  end

  defp validata_params_length(changeset, qctp, tp) do
    tp = case tp do
      nil -> []
      tp -> tp
    end
    case length(Map.keys(qctp)) == length(tp) do
      true -> {:ok, changeset}
      false -> {:error, changeset |> add_error(:type_params, "Length of type params do not match: #{inspect(qctp)} - #{inspect(tp)}")}
    end
  end

  defp do_validate_params_keys(changeset, qctp, tp) do
    qctp_tuple_list = Enum.map(qctp, fn({k, v}) ->
      {k, get_type(v)}
    end)
    validate_params_keys(changeset, qctp_tuple_list, tp)
  end

  defp validate_params_keys(_, _, _, {:error, error}), do: {:error, error}
  defp validate_params_keys(changeset, [], _), do: {:ok, changeset}
  defp validate_params_keys(changeset, [{k, v}|tail], tp) do
    system_param = Enum.find(tp, fn(param) ->
      param["name"] == k
    end)
    cond do
      system_param == nil -> validate_params_keys(changeset, nil, nil, {:error, "Element not found"})
      system_param["type"] != v -> validate_params_keys(changeset, nil, nil, {:error, "Type does not match"})
      true -> validate_params_keys(changeset, tail, tp)
    end
  end

  defp get_type(value) when is_integer(value), do: "integer"
  defp get_type(value) when is_number(value), do: "numeric"
  defp get_type(value) when is_float(value), do: "float"
  defp get_type(value) when is_list(value), do: "list"
  defp get_type(value) when is_boolean(value), do: "boolean"
  defp get_type(value) do
    case validate_date(value) do
      {:ok, format} -> format
      _ -> "string"
    end
  end

  defp validate_date(value) do
    case is_date?(value) do
      {:ok, format} -> {:ok, format}
      _ -> is_datetime?(value)
    end
  end

  defp is_date?(value) do
    case Timex.parse(value, @date_format, :strftime) do
      {:ok, _} -> {:ok, "date"}
      _ -> {:error, value}
    end
  end

  defp is_datetime?(value) do
    case Timex.parse(value, @datetime_format, :strftime) do
      {:ok, _} -> {:ok, "datetime"}
      _ -> {:error, value}
    end
  end

end
