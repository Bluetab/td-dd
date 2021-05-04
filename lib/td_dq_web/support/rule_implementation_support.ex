defmodule TdDqWeb.RuleImplementationSupport do
  @moduledoc """
  Support module for decoding Base64 encoded rule implementation parameters.
  """

  @encoded_fields ["dataset", "population", "validations"]

  @doc """
  Decodes base64 encoded parameters.

  ## Examples

      iex> raw_content = %{
      ...>   "dataset" => "UEFSVElFUyBQIFdIRVJFIFAuVFlQRSA9PSAncGVyc29uJw==",
      ...>   "population" => nil,
      ...>   "validations" => "UC5QRVJTT05fSUQgSVMgTk9UIE5VTEw="
      ...> }
      iex> RuleImplementationSupport.decode(%{"system" => 2, "raw_content" => raw_content})
      %{
        "system" => 2,
        "raw_content" => %{
          "dataset" => "PARTIES P WHERE P.TYPE == 'person'",
          "population" => nil,
          "validations" => "P.PERSON_ID IS NOT NULL"
        }
      }

  """
  def decode(params)

  def decode(%{"raw_content" => %{} = content} = params) do
    %{params | "raw_content" => decode(content, @encoded_fields)}
  end

  def decode(%{} = params), do: params

  defp decode(content, fields) do
    fields
    |> Enum.map(&Map.get(content, &1))
    |> Enum.zip(fields)
    |> Enum.reject(fn {value, _field} -> is_nil(value) end)
    |> Enum.reduce(content, fn {value, field}, acc ->
      case Base.decode64(value) do
        {:ok, decoded} -> Map.put(acc, field, decoded)
        :error -> acc
      end
    end)
  end
end
