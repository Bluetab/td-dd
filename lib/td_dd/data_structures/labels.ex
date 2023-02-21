defmodule TdDd.DataStructures.Labels do
  @moduledoc """
  The DataStructureLink Labels context
  """

  alias TdDd.Repo

  alias TdDd.DataStructures.Label

  defdelegate authorize(action, user, params), to: __MODULE__.Policy

  def list_labels do
    Repo.all(Label)
  end
end
