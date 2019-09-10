defmodule TdDq.Repo.Migrations.RemoveFieldFromPath do
  use Ecto.Migration

  import Ecto.Query

  alias TdDq.Repo

  def change do
    from(ri in "rule_implementations")
    |> where([ri], is_nil(ri.deleted_at))
    |> select([ri], %{id: ri.id, system_params: ri.system_params})
    |> Repo.all()
    |> Enum.filter(&with_path/1)
    |> Enum.map(&delete_field/1)
    |> Enum.map(&update_system_params/1)
  end

  defp with_path(%{system_params: system_params}) when system_params == %{}, do: false

  defp with_path(%{system_params: nil}), do: false

  defp with_path(%{system_params: system_params}) do
    case field_in_path(system_params) do
      [] -> false
      _ -> true
    end
  end

  defp field_in_path(system_params) do
    Enum.filter(
      system_params,
      fn {_, value} ->
        name = Map.get(value, "name")
        Map.has_key?(value, "path") and name in Enum.take(Map.get(value, "path"), -1)
      end
    )
  end

  defp delete_field(%{id: id, system_params: system_params}) do
    params =
      system_params
      |> field_in_path()
      |> Enum.map(fn {key, value} ->
        path =
          value
          |> Map.get("path")
          |> Enum.slice(0..-2)

        param = Map.put(value, "path", path)

        {key, param}
      end)
      |> Enum.into(system_params)

    %{id: id, system_params: params}
  end

  defp update_system_params(%{id: id, system_params: system_params}) do 
    from(ri in "rule_implementations")
      |> update([ri], set: [system_params: ^system_params])
      |> where([ri], ri.id == ^id)
      |> Repo.update_all([])
  end
end
