defprotocol CustomProtocol do
  @doc """
  Returns the size of the data structure.
  """
  def size(t)

  @doc """
  Checks if the data structure is empty.
  """
  def empty?(t)

  @doc """
  Converts the data structure to a list.
  """
  def to_list(t)
end
