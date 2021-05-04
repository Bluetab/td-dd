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
    Multi.new()
    |> Multi.insert(:classifier, Classifier.changeset(params))
    |> Multi.run(:classifications, &classify/2)
    |> Repo.transaction()
  end

  @doc "Deletes the specified `Classifier`"
  @spec delete_classifier(Classifier.t()) :: {:ok, Classifier.t()} | {:error, changeset}
  def delete_classifier(%Classifier{} = classifier) do
    Repo.delete(classifier)
  end

  @spec classify(Ecto.Repo.t(), %{required(Multi.name()) => any()}) ::
          {:ok, map} | {:error, Multi.name(), any, %{required(Multi.name()) => any()}}
  def classify(_repo, %{classifier: classifier}) do
    classify(classifier)
  end

  @spec classify(Classifier.t()) ::
          {:ok, map} | {:error, Multi.name(), any, %{required(Multi.name()) => any()}}
  def classify(%Classifier{} = classifier) do
    query = structure_query(classifier)

    %{rules: rules} = Repo.preload(classifier, :rules)

    rules
    |> Enum.sort_by(& &1.priority)
    |> Enum.reduce(Multi.new(), &apply_rule(&1, &2, query))
    |> Repo.transaction()
  end

  @spec apply_rule(Rule.t(), Multi.t(), Ecto.Queryable.t()) :: Multi.t()
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
  @spec structure_query(Classifier.t()) :: Ecto.Queryable.t()
  def structure_query(%Classifier{system_id: system_id} = classifier) do
    %{filters: filters} = Repo.preload(classifier, :filters)

    query =
      DataStructureVersion
      |> join(:inner, [dsv], ds in assoc(dsv, :data_structure))
      |> where([_, ds], ds.system_id == ^system_id)

    Enum.reduce(filters, query, &do_filter/2)
  end

  @spec do_filter(Rule.t() | Filter.t(), Ecto.Queryable.t()) :: Ecto.Queryable.t()
  defp do_filter(rule_or_filter, query)

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
