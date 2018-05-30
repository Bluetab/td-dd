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
  def get_quality_rule!(id), do: Repo.preload(Repo.get!(QualityRule, id), [:quality_rule_type, :quality_control])

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

  alias TdDq.QualityRules.QualityRuleType

  @doc """
  Returns the list of quality_rule_type.

  ## Examples

      iex> list_quality_rule_types()
      [%QualityRuleType{}, ...]

  """
  def list_quality_rule_types do
    Repo.all(QualityRuleType)
  end

  @doc """
  Gets a single quality_rule_type.

  Raises `Ecto.NoResultsError` if the Quality rule types does not exist.

  ## Examples

      iex> get_quality_rule_type!(123)
      %QualityRuleType{}

      iex> get_quality_rule_type!(456)
      ** (Ecto.NoResultsError)

  """
  def get_quality_rule_type!(id), do: Repo.get!(QualityRuleType, id)

  def get_quality_rule_type_by_name(name) do
    Repo.get_by(QualityRuleType, name: name)
  end

  @doc """
  Creates a quality_rule_type.

  ## Examples

      iex> create_quality_rule_type(%{field: value})
      {:ok, %QualityRuleType{}}

      iex> create_quality_rule_type(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_quality_rule_type(attrs \\ %{}) do
    %QualityRuleType{}
    |> QualityRuleType.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a quality_rule_type.

  ## Examples

      iex> update_quality_rule_type(quality_rule_type, %{field: new_value})
      {:ok, %QualityRuleType{}}

      iex> update_quality_rule_type(quality_rule_type, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_quality_rule_type(%QualityRuleType{} = quality_rule_type, attrs) do
    quality_rule_type
    |> QualityRuleType.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a QualityRuleType.

  ## Examples

      iex> delete_quality_rule_type(quality_rule_type)
      {:ok, %QualityRuleType{}}

      iex> delete_quality_rule_type(quality_rule_type)
      {:error, %Ecto.Changeset{}}

  """
  def delete_quality_rule_type(%QualityRuleType{} = quality_rule_type) do
    Repo.delete(quality_rule_type)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking quality_rule_type changes.

  ## Examples

      iex> change_quality_rule_type(quality_rule_type)
      %Ecto.Changeset{source: %QualityRuleType{}}

  """
  def change_quality_rule_type(%QualityRuleType{} = quality_rule_type) do
    QualityRuleType.changeset(quality_rule_type, %{})
  end
end
