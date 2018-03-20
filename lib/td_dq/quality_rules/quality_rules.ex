defmodule TdDq.QualityRules do
  @moduledoc """
  The QualityRules context.
  """

  import Ecto.Query, warn: false
  alias TdDq.Repo

  alias TdDq.QualityRules.QualityRule

  @doc """
  Returns the list of quality_rules.

  ## Examples

      iex> list_quality_rules()
      [%QualityRule{}, ...]

  """
  def list_quality_rules do
    Repo.all(QualityRule)
  end

  @doc """
  Gets a single quality_rule.

  Raises `Ecto.NoResultsError` if the Quality rule does not exist.

  ## Examples

      iex> get_quality_rule!(123)
      %QualityRule{}

      iex> get_quality_rule!(456)
      ** (Ecto.NoResultsError)

  """
  def get_quality_rule!(id), do: Repo.get!(QualityRule, id)

  @doc """
  Creates a quality_rule.

  ## Examples

      iex> create_quality_rule(%{field: value})
      {:ok, %QualityRule{}}

      iex> create_quality_rule(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_quality_rule(attrs \\ %{}) do
    %QualityRule{}
    |> QualityRule.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a quality_rule.

  ## Examples

      iex> update_quality_rule(quality_rule, %{field: new_value})
      {:ok, %QualityRule{}}

      iex> update_quality_rule(quality_rule, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_quality_rule(%QualityRule{} = quality_rule, attrs) do
    quality_rule
    |> QualityRule.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a QualityRule.

  ## Examples

      iex> delete_quality_rule(quality_rule)
      {:ok, %QualityRule{}}

      iex> delete_quality_rule(quality_rule)
      {:error, %Ecto.Changeset{}}

  """
  def delete_quality_rule(%QualityRule{} = quality_rule) do
    Repo.delete(quality_rule)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking quality_rule changes.

  ## Examples

      iex> change_quality_rule(quality_rule)
      %Ecto.Changeset{source: %QualityRule{}}

  """
  def change_quality_rule(%QualityRule{} = quality_rule) do
    QualityRule.changeset(quality_rule, %{})
  end
end
