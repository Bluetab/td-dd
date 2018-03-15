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
  def list_quality_controls do
    Repo.all(QualityControl)
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
  def get_quality_control!(id), do: Repo.get!(QualityControl, id)

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
end
