defmodule MyImpl do
  @behaviour MyBehaviour

  @impl true
  def init(arg) do
    {:ok, arg}
  end

  @impl MyBehaviour
  def handle_call(_msg, state) do
    {:reply, :ok, state}
  end
end
