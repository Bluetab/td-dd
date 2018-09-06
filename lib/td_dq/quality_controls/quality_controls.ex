defmodule TdDq.QualityControls do
  @moduledoc """
  The QualityControls context.
  """

  import Ecto.Query, warn: false
  alias TdDq.Repo

  alias TdDq.QualityControls.QualityControl
  alias TdDq.QualityControls.QualityControlsResults

  @doc """
  Returns the list of quality_controls.

  ## Examples

      iex> list_quality_controls()
      [%QualityControl{}, ...]

  """
  def list_quality_controls(params) do
    fields = QualityControl.__schema__(:fields)
    dynamic = filter(params, fields)
    query = from(
      p in QualityControl,
      where: ^dynamic
    )

    query
      |> Repo.all()
      |> Repo.preload(:quality_rules)
  end

  @doc """
  Gets a single quality_control.

  Raises `Ecto.NoResultsError` if the Quality control does not exist.

  ## Examples

      iex> get_quality_control!(123)
      %QualityControl{}

      iex> get_quality_control!(456)
      ** (Ecto.NoResultsError)

  """
  def get_quality_control!(id), do: Repo.preload(Repo.get!(QualityControl, id), :quality_rules)

  @doc """
  Creates a quality_control.

  ## Examples

      iex> create_quality_control(%{field: value})
      {:ok, %QualityControl{}}

      iex> create_quality_control(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_quality_control(attrs \\ %{}) do
    %QualityControl{}
    |> QualityControl.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a quality_control.

  ## Examples

      iex> update_quality_control(quality_control, %{field: new_value})
      {:ok, %QualityControl{}}

      iex> update_quality_control(quality_control, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_quality_control(%QualityControl{} = quality_control, attrs) do
    quality_control
    |> QualityControl.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a QualityControl.

  ## Examples

      iex> delete_quality_control(quality_control)
      {:ok, %QualityControl{}}

      iex> delete_quality_control(quality_control)
      {:error, %Ecto.Changeset{}}

  """
  def delete_quality_control(%QualityControl{} = quality_control) do
    Repo.delete(quality_control)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking quality_control changes.

  ## Examples

      iex> change_quality_control(quality_control)
      %Ecto.Changeset{source: %QualityControl{}}

  """
  def change_quality_control(%QualityControl{} = quality_control) do
    QualityControl.changeset(quality_control, %{})
  end

  def list_quality_controls_results do
    Repo.all(QualityControlsResults)
  end

  def list_concept_quality_controls(params) do
    fields = QualityControl.__schema__(:fields)
    dynamic = filter(params, fields)

    query = from(
      p in QualityControl,
      where: ^dynamic,
      order_by: [desc: :business_concept_id]
    )

    query
    |> Repo.all()
    |> Repo.preload(:quality_rules)
  end

  # TODO: Search by implemnetation id
  def get_last_quality_controls_result(business_concept_id,
                                       quality_control_name,
                                       system,
                                       structure_name,
                                       field_name) do
    QualityControlsResults
    |> where([r], r.business_concept_id == ^business_concept_id and
                  r.quality_control_name == ^quality_control_name and
                  r.system == ^system and
                  r.structure_name == ^structure_name and
                  r.field_name == ^field_name)
    |> order_by(desc: :date)
    |> limit(1)
    |> Repo.one()
  end

  defp filter(params, fields) do
    dynamic = true

    Enum.reduce(Map.keys(params), dynamic, fn x, acc ->
      key_as_atom = String.to_atom(x)

      case Enum.member?(fields, key_as_atom) do
        true -> dynamic([p], field(p, ^key_as_atom) == ^params[x] and ^acc)
        false -> acc
      end
    end)
  end
end
