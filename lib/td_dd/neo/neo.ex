defmodule TdDd.Neo do
  @moduledoc """
  Integration with Neo4j
  """

  alias Bolt.Sips

  @doc """
  Returns all nodes of a specified type.
  """
  def nodes(type) do
    "MATCH (n:#{type}) RETURN n"
    |> query()
  end

  @doc """
  Returns all relations of a specified type.
  """
  def relations(type) do
    "MATCH ()-[r:#{type}]->() RETURN r"
    |> query()
  end

  @doc """
  Returns the store creation date of the Neo4j instance.
  """
  def store_creation_date, do: jmx_datetime_query("StoreCreationDate")

  @doc """
  Returns the kernel start date of the Neo4j instance.
  """
  def kernel_start_time, do: jmx_datetime_query("KernelStartTime")

  defp query(q, transform \\ &Map.from_struct/1)

  defp query(q, transform) when is_function(transform) do
    Sips.conn()
    |> Sips.query!(q, %{}, timeout: 120_000)
    |> Map.get(:records)
    |> Enum.flat_map(& &1)
    |> Enum.map(transform)
  end

  defp jmx_datetime_query(attribute, instance \\ "kernel#0", name \\ "Kernel") do
    attribute
    |> jmx_query(instance, name)
    |> DateTime.from_unix!(:millisecond)
  end

  defp jmx_query(attribute, instance, name) do
    """
    call dbms.queryJmx("org.neo4j:instance=#{instance},name=#{name}") yield attributes
    return attributes["#{attribute}"]["value"]
    """
    |> query(fn v -> v end)
    |> hd
  end
end
