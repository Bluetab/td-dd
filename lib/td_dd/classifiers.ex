defmodule TdDd.Classifiers do
  @moduledoc """
  The Classifiers context.
  """

  alias TdDd.Classifiers.Classifier
  alias TdDd.Classifiers.Filter
  alias TdDd.Classifiers.Rule
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
end
