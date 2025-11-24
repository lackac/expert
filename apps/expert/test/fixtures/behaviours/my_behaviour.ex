defmodule MyBehaviour do
  @moduledoc """
  A simple behaviour for testing.
  """

  @callback init(term()) :: {:ok, term()} | {:error, term()}
  @callback handle_call(term(), term()) :: {:reply, term(), term()}
  @callback terminate(term()) :: :ok
  @optional_callbacks terminate: 1
end
