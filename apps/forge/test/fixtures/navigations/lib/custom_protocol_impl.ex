defimpl CustomProtocol, for: List do
  def size(list) do
    length(list)
  end

  def empty?(list) do
    list == []
  end

  def to_list(list) do
    list
  end
end

defimpl CustomProtocol, for: Map do
  def size(map) do
    map_size(map)
  end

  def empty?(map) do
    map_size(map) == 0
  end

  def to_list(map) do
    Map.to_list(map)
  end
end
