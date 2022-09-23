defmodule TdDdWeb.Resolvers.StructureNotes do
  @moduledoc """
  Absinthe resolvers for structure notes and related entities
  """

  alias TdDd.DataStructures.StructureNotes

  def structure_notes(_parent, args, resolution) do
    case claims(resolution) do
      nil ->
        {:error, :unauthorized}

      %{} = claims ->
        filter =
          args
          |> Map.get(:filter, %{})
          |> Map.new(fn {key, value} -> {Atom.to_string(key), value} end)

        structure_notes =
          StructureNotes.list_structure_notes(filter)
          |> Enum.filter(&can_take_action(claims, &1))

        {:ok, structure_notes}
    end
  end

  defp claims(%{context: %{claims: claims}}), do: claims
  defp claims(_), do: nil

  defp can_take_action(claims, %{status: :draft, data_structure: data_structure}) do
    Bodyguard.permit?(StructureNotes, :publish_draft, claims, data_structure) or
      Bodyguard.permit?(StructureNotes, :edit, claims, data_structure)
  end

  defp can_take_action(claims, %{status: :pending_approval, data_structure: data_structure}) do
    Bodyguard.permit?(StructureNotes, :publish, claims, data_structure)
  end

  defp can_take_action(claims, %{status: :rejected, data_structure: data_structure}) do
    Bodyguard.permit?(StructureNotes, :unreject, claims, data_structure)
  end

  defp can_take_action(_claims, _), do: false
end
