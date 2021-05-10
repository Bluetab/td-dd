defmodule TdDdWeb.ClassifierView do
  use TdDdWeb, :view

  @rule_props [:path, :priority, :class]

  def render("index.json", %{classifiers: classifiers}) do
    %{data: render_many(classifiers, __MODULE__, "classifier.json")}
  end

  def render("show.json", %{classifier: classifier}) do
    %{data: render_one(classifier, __MODULE__, "classifier.json")}
  end

  def render("classifier.json", %{classifier: classifier}) do
    %{
      id: classifier.id,
      name: classifier.name,
      filters: render_many(classifier.filters, __MODULE__, "filter.json", as: :filter),
      rules: render_many(classifier.rules, __MODULE__, "rule.json", as: :rule)
    }
  end

  def render("filter.json", %{filter: %{values: [_ | _] = values, path: path}}) do
    %{
      path: path,
      values: values
    }
  end

  def render("filter.json", %{filter: %{regex: regex, path: path}}) when is_binary(regex) do
    %{
      path: path,
      regex: regex
    }
  end

  def render("rule.json", %{rule: %{values: [_ | _] = values} = rule}) do
    rule
    |> Map.take(@rule_props)
    |> Map.put(:values, values)
  end

  def render("rule.json", %{rule: %{regex: regex} = rule}) when is_binary(regex) do
    rule
    |> Map.take(@rule_props)
    |> Map.put(:regex, regex)
  end
end
