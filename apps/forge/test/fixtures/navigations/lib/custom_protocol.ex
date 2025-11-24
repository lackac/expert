defprotocol CustomProtocol do
  @doc """
  Returns the size of the data structure.
  """
  @callback size(t) :: non_neg_integer()

  @doc """
  Checks if the data structure is empty.
  """
  @callback empty?(t) :: boolean()

  @doc """
  Converts the data structure to a list.
  """
  @callback to_list(t) :: [term()]
end
