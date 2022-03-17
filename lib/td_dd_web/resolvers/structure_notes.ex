defmodule TdDdWeb.Resolvers.StructureNotes do
  @moduledoc """
  Absinthe resolvers for structure_notes and related entities
  """

  import Canada, only: [can?: 2]

  alias TdDd.DataStructures.StructureNotes

  def structure_notes(_parent, args, resolution) do
    case {:claims, claims(resolution)} do
      {:claims, %{} = claims} ->
        filter =
          args
          |> Map.get(:filter, %{})
          |> Enum.map(fn {key, value} -> {Atom.to_string(key), value} end)
          |> Map.new()

        structure_notes =
          StructureNotes.list_structure_notes(filter)
          |> Enum.filter(&can_take_action(claims, &1))

        {:ok, structure_notes}

      {:claims, nil} ->
        {:error, :unauthorized}
    end
  end

  defp claims(%{context: %{claims: claims}}), do: claims
  defp claims(_), do: nil

  defp can_take_action(claims, %{status: :draft, data_structure: data_structure}) do
    can?(claims, publish_structure_note_from_draft(data_structure)) or
      can?(claims, edit_structure_note(data_structure))
  end

  defp can_take_action(claims, %{status: :pending_approval, data_structure: data_structure}) do
    can?(claims, publish_structure_note(data_structure))
  end

  defp can_take_action(claims, %{status: :rejected, data_structure: data_structure}) do
    can?(claims, unreject_structure_note(data_structure))
  end

  defp can_take_action(_claims, _), do: false
end
