defmodule TdDq.Rules do
  @moduledoc """
  The Rules context.
  """

  import Ecto.Query, warn: false
  alias TdDq.Repo

  alias TdDq.Rules.Rule
  alias TdDq.Rules.RuleImplementation
  alias TdDq.Rules.RuleResult

  @doc """
  Returns the list of rule_implementations.

  ## Examples

      iex> list_rules()
      [%Rule{}, ...]

  """
  def list_rules(params) do
    fields = Rule.__schema__(:fields)
    dynamic = filter(params, fields)
    query = from(
      p in Rule,
      where: ^dynamic
    )

    query
      |> Repo.all()
      |> Repo.preload(:rule_implementations)
  end

  @doc """
  Gets a single rule.

  Raises `Ecto.NoResultsError` if the Quality control does not exist.

  ## Examples

      iex> get_rule!(123)
      %Rule{}

      iex> get_rule!(456)
      ** (Ecto.NoResultsError)

  """
  def get_rule!(id), do: Repo.preload(Repo.get!(Rule, id), :rule_implementations)

  @doc """
  Creates a rule.

  ## Examples

      iex> create_rule(%{field: value})
      {:ok, %Rule{}}

      iex> create_rule(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_rule(attrs \\ %{}) do
    %Rule{}
    |> Rule.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a rule.

  ## Examples

      iex> update_rule(rule, %{field: new_value})
      {:ok, %Rule{}}

      iex> update_rule(rule, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_rule(%Rule{} = rule, attrs) do
    rule
    |> Rule.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Rule.

  ## Examples

      iex> delete_rule(rule)
      {:ok, %Rule{}}

      iex> delete_rule(rule)
      {:error, %Ecto.Changeset{}}

  """
  def delete_rule(%Rule{} = rule) do
    Repo.delete(rule)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking rule changes.

  ## Examples

      iex> change_rule(rule)
      %Ecto.Changeset{source: %Rule{}}

  """
  def change_rule(%Rule{} = rule) do
    Rule.changeset(rule, %{})
  end

  def list_rule_results do
    Repo.all(RuleResult)
  end

  def list_concept_rules(params) do
    fields = Rule.__schema__(:fields)
    dynamic = filter(params, fields)

    query = from(
      p in Rule,
      where: ^dynamic,
      order_by: [desc: :business_concept_id]
    )

    query
    |> Repo.all()
    |> Repo.preload(:rule_implementations)
  end

  # TODO: Search by implemnetation id
  def get_concept_last_rule_result(business_concept_id,
                                       rule,
                                       system,
                                       structure_name,
                                       field_name) do
    RuleResult
    |> where([r], r.business_concept_id == ^business_concept_id and
                  r.rule == ^rule and
                  r.system == ^system and
                  r.structure_name == ^structure_name and
                  r.field_name == ^field_name)
    |> order_by(desc: :date)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Returns the list of rule_implementations.

  ## Examples

      iex> list_rule_implementations()
      [%RuleImplementation{}, ...]

  """
  def list_rule_implementations do
    Repo.all(RuleImplementation)
  end

  @doc """
  Gets a single rule_implementation.

  Raises `Ecto.NoResultsError` if the Rule does not exist.

  ## Examples

      iex> get_rule_implementation!(123)
      %RuleImplementation{}

      iex> get_rule_implementation!(456)
      ** (Ecto.NoResultsError)

  """
  def get_rule_implementation!(id), do: Repo.preload(Repo.get!(RuleImplementation, id), [:rule])

  @doc """
  Creates a rule_implementation.

  ## Examples

      iex> create_rule_implementation(%{field: value})
      {:ok, %RuleImplementation{}}

      iex> create_rule_implementation(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_rule_implementation(attrs \\ %{}) do
    %RuleImplementation{}
    |> RuleImplementation.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a rule_implementation.

  ## Examples

      iex> update_rule_implementation(rule_implementation, %{field: new_value})
      {:ok, %RuleImplementation{}}

      iex> update_rule_implementation(rule_implementation, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_rule_implementation(%RuleImplementation{} = rule_implementation, attrs) do
    rule_implementation
    |> RuleImplementation.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a RuleImplementation.

  ## Examples

      iex> delete_rule_implementation(rule_implementation)
      {:ok, %RuleImplementation{}}

      iex> delete_rule_implementation(rule_implementation)
      {:error, %Ecto.Changeset{}}

  """
  def delete_rule_implementation(%RuleImplementation{} = rule_implementation) do
    Repo.delete(rule_implementation)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking rule_implementation changes.

  ## Examples

      iex> change_rule_implementation(rule_implementation)
      %Ecto.Changeset{source: %RuleImplementation{}}

  """
  def change_rule_implementation(%RuleImplementation{} = rule_implementation) do
    RuleImplementation.changeset(rule_implementation, %{})
  end

  alias TdDq.Rules.RuleType

  @doc """
  Returns the list of rule_type.

  ## Examples

      iex> list_rule_types()
      [%RuleType{}, ...]

  """
  def list_rule_types do
    Repo.all(RuleType)
  end

  @doc """
  Gets a single rule_type.

  Raises `Ecto.NoResultsError` if the Rule types does not exist.

  ## Examples

      iex> get_rule_type!(123)
      %RuleType{}

      iex> get_rule_type!(456)
      ** (Ecto.NoResultsError)

  """
  def get_rule_type!(id), do: Repo.get!(RuleType, id)

  def get_rule_type_by_name(name) do
    Repo.get_by(RuleType, name: name)
  end

  @doc """
  Creates a rule_type.

  ## Examples

      iex> create_rule_type(%{field: value})
      {:ok, %RuleType{}}

      iex> create_rule_type(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_rule_type(attrs \\ %{}) do
    %RuleType{}
    |> RuleType.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a rule_type.

  ## Examples

      iex> update_rule_type(rule_type, %{field: new_value})
      {:ok, %RuleType{}}

      iex> update_rule_type(rule_type, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_rule_type(%RuleType{} = rule_type, attrs) do
    rule_type
    |> RuleType.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a RuleType.

  ## Examples

      iex> delete_rule_type(rule_type)
      {:ok, %RuleType{}}

      iex> delete_rule_type(rule_type)
      {:error, %Ecto.Changeset{}}

  """
  def delete_rule_type(%RuleType{} = rule_type) do
    Repo.delete(rule_type)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking rule_type changes.

  ## Examples

      iex> change_rule_type(rule_type)
      %Ecto.Changeset{source: %RuleType{}}

  """
  def change_rule_type(%RuleType{} = rule_type) do
    RuleType.changeset(rule_type, %{})
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
