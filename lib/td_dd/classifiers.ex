defmodule TdDd.Classifiers do
  @moduledoc """
  The Classifiers context.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias TdDd.Classifiers.Classifier
  alias TdDd.Classifiers.Filter
  alias TdDd.Classifiers.Rule
  alias TdDd.DataStructures.Classification
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.Repo

  @typep changeset :: Ecto.Changeset.t()

  @doc "Creates a `Classifier` using the specified parameters"
  @spec create_classifier(map) :: {:ok, Classifier.t()} | {:error, changeset}
  def create_classifier(%{} = params) do
    params
    |> Classifier.changeset()
    |> Repo.insert()
  end

  @doc "Creates a `Filter` using the specified parameters"
  @spec create_filter(Classifier.t(), map) :: {:ok, Filter.t()} | {:error, changeset}
  def create_filter(%Classifier{id: classifier_id}, %{} = params) do
    %Filter{classifier_id: classifier_id}
    |> Filter.changeset(params)
    |> Repo.insert()
  end

  @doc "Creates a `Rule` using the specified parameters"
  @spec create_rule(Classifier.t(), map) :: {:ok, Rule.t()} | {:error, changeset}
  def create_rule(%Classifier{id: classifier_id}, %{} = params) do
    %Rule{classifier_id: classifier_id}
    |> Rule.changeset(params)
    |> Repo.insert()
  end

  @doc "Deletes the specified `Classifier`"
  @spec delete_classifier(Classifier.t()) :: {:ok, Classifier.t()} | {:error, changeset}
  def delete_classifier(%Classifier{} = classifier) do
    Repo.delete(classifier)
  end

  @doc "Deletes the specified `Filter`"
  @spec delete_filter(Filter.t()) :: {:ok, Filter.t()} | {:error, changeset}
  def delete_filter(%Filter{} = filter) do
    Repo.delete(filter)
  end

  @doc "Deletes the specified `Rule`"
  @spec delete_rule(Rule.t()) :: {:ok, Rule.t()} | {:error, changeset}
  def delete_rule(%Rule{} = rule) do
    Repo.delete(rule)
  end

  def classify(%Classifier{} = classifier) do
    # Query  structures matching classifier filter
    query = structure_query(classifier)

    # Group by matching rule
    %{rules: rules} = Repo.preload(classifier, :rules)

    rules
    |> Enum.sort_by(& &1.priority)
    |> Enum.reduce(multi(classifier), &apply_rule(&1, &2, query))
    |> Repo.transaction()

    # insert_all / on_conflict

    # remove where rule_id is null
  end

  defp multi(%Classifier{id: id}) do
    query =
      Classification
      |> where(classifier_id: ^id)
      |> where([c], is_nil(c.rule_id))

    Multi.new()
    |> Multi.delete_all(:delete_existing, query)
  end

  defp apply_rule(%Rule{class: class, classifier_id: classifier_id, id: id} = rule, multi, query) do
    Multi.run(multi, class, fn repo, %{} ->
      source =
        rule
        |> do_filter(query)
        |> select([dsv, ds], %{
          class: ^class,
          data_structure_version_id: dsv.id,
          classifier_id: ^classifier_id,
          rule_id: ^id,
          inserted_at: fragment("now()"),
          updated_at: fragment("now()")
        })

      res =
        repo.insert_all(Classification, source,
          conflict_target: [:data_structure_version_id, :classifier_id],
          on_conflict: {:replace, [:class, :rule_id, :updated_at]},
          returning: true
        )

      {:ok, res}
    end)
  end

  @doc """
  Build a query for data structure versions matching the classifier's system and
  filters.
  """
  def structure_query(%Classifier{system_id: system_id} = classifier) do
    %{filters: filters} = Repo.preload(classifier, :filters)

    q =
      DataStructureVersion
      |> join(:inner, [dsv], ds in assoc(dsv, :data_structure))
      |> where([_, ds], ds.system_id == ^system_id)

    Enum.reduce(filters, q, &do_filter/2)
  end

  defp do_filter(%{path: ["metadata" | path], values: [_ | _] = values}, q) do
    where(
      q,
      [dsv],
      fragment("jsonb_extract_path_text(?, variadic ?)", dsv.metadata, ^path) in ^values
    )
  end

  defp do_filter(%{path: ["external_id"], values: [_ | _] = values}, q) do
    where(q, [dsv, ds], ds.external_id in ^values)
  end

  defp do_filter(%{path: [property], values: [_ | _] = values}, q) do
    prop = String.to_existing_atom(property)
    where(q, [dsv], field(dsv, ^prop) in ^values)
  end

  defp do_filter(%{path: ["metadata" | path], regex: %{source: source}}, q) do
    where(
      q,
      [dsv],
      fragment("jsonb_extract_path_text(?, variadic ?) ~ ?", dsv.metadata, ^path, ^source)
    )
  end

  defp do_filter(%{path: ["external_id"], regex: %{source: source}}, q) do
    where(q, [_dsv, ds], fragment("? ~ ?", ds.external_id, ^source))
  end

  defp do_filter(%{path: [property], regex: %{source: source}}, q) do
    prop = String.to_existing_atom(property)
    where(q, [dsv], fragment("? ~ ?", field(dsv, ^prop), ^source))
  end
end
