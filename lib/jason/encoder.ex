defimpl Jason.Encoder, for: Tuple do
  def encode(value, opts) do
    Jason.Encode.list(Tuple.to_list(value), opts)
  end
end
