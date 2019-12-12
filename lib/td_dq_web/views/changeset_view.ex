defmodule TdDqWeb.ChangesetView do
  use TdDqWeb, :view
  import TdDqWeb.ChangesetSupport

  def render("error.json", %{changeset: changeset, prefix: prefix}) do
    %{errors: translate_errors(changeset, prefix)}
  end

  def render("error.json", %{changeset: changeset}) do
    %{errors: translate_errors(changeset)}
  end

  def render("nested_errors.json", %{errors: errors, prefix: prefix}) do
    errors =
      errors
      |> Map.keys()
      |> Enum.map(&compose_errors(errors, &1, prefix))
      |> List.flatten()
      |> Enum.filter(fn error -> error != [] end)

    %{errors: errors}
  end

  defp compose_errors(errors, errors_key, prefix) do
    errors
    |> Map.get(errors_key, [])
    |> Enum.map(fn error ->
      case is_map(error) do
        true ->
          error_info = flatten(error)
          field = error_info |> Map.keys() |> List.first()
          error = Map.get(error_info, field)
          %{name: "#{prefix}.#{errors_key}.#{field}.#{error}"}

        _ ->
          %{name: "#{prefix}.#{errors_key}.#{error}"}
      end
    end)
  end

  defp flatten(map) when is_map(map) do
    map
    |> to_list_of_tuples
    |> Enum.into(%{})
  end

  defp to_list_of_tuples(m) do
    m
    |> Enum.map(&process/1)
    |> List.flatten()
  end

  defp process({key, sub_map}) when is_map(sub_map) do
    for {sub_key, value} <- sub_map do
      {join(key, sub_key), value}
    end
  end

  defp process({key, value}) do
    {key, value}
  end

  defp join(a, b) do
    to_string(a) <> "." <> to_string(b)
  end
end
