defmodule ArityFallback do
  @moduledoc """
  Test fixture for best-effort arity matching.
  Contains functions with multiple arities to test fallback behavior.
  """

  # Function with arity 1 and 3 (no arity 2)
  def process(value) do
    {:ok, value}
  end

  def process(value, opts, callback) do
    callback.(value, opts)
  end

  # Function with arities 0, 2, 4
  def transform() do
    :default
  end

  def transform(a, b) do
    {a, b}
  end

  def transform(a, b, c, d) do
    {a, b, c, d}
  end

  # Function with many arities for tie-breaker test
  def calculate(a) do
    a
  end

  def calculate(a, b) do
    a + b
  end

  def calculate(a, b, c) do
    a + b + c
  end

  def calculate(a, b, c, d) do
    a + b + c + d
  end

  def calculate(a, b, c, d, e) do
    a + b + c + d + e
  end

  # Single arity function
  def single_arity(x, y, z) do
    x + y + z
  end
end
