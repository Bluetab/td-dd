defmodule TdDq.Rules do
  @moduledoc """
  The Rules context.
  """

  import Ecto.Query, warn: false
  alias TdDq.Repo

  alias TdDq.Rules.Rule
  alias TdDq.Rules.RuleImplementation

  @doc """
  Returns the list of quality_controls.

  ## Examples

      iex> list_quality_controls()
      [%Rule{}, ...]

  """
  def list_quality_controls do
    Rule
      |> Repo.all()
      |> Repo.preload(:quality_rules)
  end

  @doc """
  Gets a single quality_control.

  Raises `Ecto.NoResultsError` if the Quality control does not exist.

  ## Examples

      iex> get_quality_control!(123)
      %Rule{}

      iex> get_quality_control!(456)
      ** (Ecto.NoResultsError)

  """
  def get_quality_control!(id), do: Repo.preload(Repo.get!(Rule, id), :quality_rules)

  @doc """
  Creates a quality_control.

  ## Examples

      iex> create_quality_control(%{field: value})
      {:ok, %Rule{}}

      iex> create_quality_control(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_quality_control(attrs \\ %{}) do
    %Rule{}
    |> Rule.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a quality_control.

  ## Examples

      iex> update_quality_control(quality_control, %{field: new_value})
      {:ok, %Rule{}}

      iex> update_quality_control(quality_control, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_quality_control(%Rule{} = quality_control, attrs) do
    quality_control
    |> Rule.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Rule.

  ## Examples

      iex> delete_quality_control(quality_control)
      {:ok, %Rule{}}

      iex> delete_quality_control(quality_control)
      {:error, %Ecto.Changeset{}}

  """
  def delete_quality_control(%Rule{} = quality_control) do
    Repo.delete(quality_control)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking quality_control changes.

  ## Examples

      iex> change_quality_control(quality_control)
      %Ecto.Changeset{source: %Rule{}}

  """
  def change_quality_control(%Rule{} = quality_control) do
    Rule.changeset(quality_control, %{})
  end

  def list_quality_controls_results do
    Repo.all(RulesResults)
  end

  def list_concept_quality_controls(business_concept_id) do
    Rule
    |> where([v], v.business_concept_id == ^business_concept_id)
    |> order_by(desc: :business_concept_id)
    |> Repo.all()
    |> Repo.preload(:quality_rules)
  end

  # TODO: Search by implemnetation id
  def get_last_quality_controls_result(business_concept_id,
                                       quality_control_name,
                                       system,
                                       structure_name,
                                       field_name) do
    RulesResults
    |> where([r], r.business_concept_id == ^business_concept_id and
                  r.quality_control_name == ^quality_control_name and
                  r.system == ^system and
                  r.structure_name == ^structure_name and
                  r.field_name == ^field_name)
    |> order_by(desc: :date)
    |> limit(1)
    |> Repo.one()
  end


  @doc """
  Returns the list of quality_rules.

  ## Examples

      iex> list_quality_rules()
      [%RuleImplementation{}, ...]

  """
  def list_quality_rules do
    Repo.all(QualityRule)
  end

  @doc """
  Gets a single quality_rule.

  Raises `Ecto.NoResultsError` if the Quality rule does not exist.

  ## Examples

      iex> get_quality_rule!(123)
      %RuleImplementation{}

      iex> get_quality_rule!(456)
      ** (Ecto.NoResultsError)

  """
  def get_quality_rule!(id), do: Repo.preload(Repo.get!(QualityRule, id), [:quality_rule_type, :quality_control])

  @doc """
  Creates a quality_rule.

  ## Examples

      iex> create_quality_rule(%{field: value})
      {:ok, %RuleImplementation{}}

      iex> create_quality_rule(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_quality_rule(attrs \\ %{}) do
    %RuleImplementation{}
    |> RuleImplementation.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a quality_rule.

  ## Examples

      iex> update_quality_rule(quality_rule, %{field: new_value})
      {:ok, %RuleImplementation{}}

      iex> update_quality_rule(quality_rule, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_quality_rule(%RuleImplementation{} = quality_rule, attrs) do
    quality_rule
    |> RuleImplementation.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a QualityRule.

  ## Examples

      iex> delete_quality_rule(quality_rule)
      {:ok, %RuleImplementation{}}

      iex> delete_quality_rule(quality_rule)
      {:error, %Ecto.Changeset{}}

  """
  def delete_quality_rule(%RuleImplementation{} = quality_rule) do
    Repo.delete(quality_rule)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking quality_rule changes.

  ## Examples

      iex> change_quality_rule(quality_rule)
      %Ecto.Changeset{source: %RuleImplementation{}}

  """
  def change_quality_rule(%RuleImplementation{} = quality_rule) do
    RuleImplementation.changeset(quality_rule, %{})
  end

  alias TdDq.Rules.RuleType

  @doc """
  Returns the list of quality_rule_type.

  ## Examples

      iex> list_quality_rule_types()
      [%RuleType{}, ...]

  """
  def list_quality_rule_types do
    Repo.all(RuleType)
  end

  @doc """
  Gets a single quality_rule_type.

  Raises `Ecto.NoResultsError` if the Quality rule types does not exist.

  ## Examples

      iex> get_quality_rule_type!(123)
      %RuleType{}

      iex> get_quality_rule_type!(456)
      ** (Ecto.NoResultsError)

  """
  def get_quality_rule_type!(id), do: Repo.get!(RuleType, id)

  def get_quality_rule_type_by_name(name) do
    Repo.get_by(RuleType, name: name)
  end

  @doc """
  Creates a quality_rule_type.

  ## Examples

      iex> create_quality_rule_type(%{field: value})
      {:ok, %RuleType{}}

      iex> create_quality_rule_type(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_quality_rule_type(attrs \\ %{}) do
    %RuleType{}
    |> RuleType.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a quality_rule_type.

  ## Examples

      iex> update_quality_rule_type(quality_rule_type, %{field: new_value})
      {:ok, %RuleType{}}

      iex> update_quality_rule_type(quality_rule_type, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_quality_rule_type(%RuleType{} = quality_rule_type, attrs) do
    quality_rule_type
    |> RuleType.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a RuleType.

  ## Examples

      iex> delete_quality_rule_type(quality_rule_type)
      {:ok, %RuleType{}}

      iex> delete_quality_rule_type(quality_rule_type)
      {:error, %Ecto.Changeset{}}

  """
  def delete_quality_rule_type(%RuleType{} = quality_rule_type) do
    Repo.delete(quality_rule_type)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking quality_rule_type changes.

  ## Examples

      iex> change_quality_rule_type(quality_rule_type)
      %Ecto.Changeset{source: %RuleType{}}

  """
  def change_quality_rule_type(%RuleType{} = quality_rule_type) do
    RuleType.changeset(quality_rule_type, %{})
  end

end
