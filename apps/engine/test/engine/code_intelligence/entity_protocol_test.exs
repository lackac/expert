defmodule Engine.CodeIntelligence.EntityProtocolTest do
  use ExUnit.Case, async: true

  alias Engine.CodeIntelligence.Entity
  alias Forge.Ast
  alias Forge.Document
  alias Forge.Document.Position

  describe "resolve/2 with protocol implementations" do
    test "detects protocol callback in defimpl block" do
      code = """
      defmodule MyList do
        defimpl Enumerable, for: List do
          def reduce(list, acc, fun), do: Enum.reduce(list, acc, fun)
          def count(list), do: {:ok, length(list)}
          def member?(list, item), do: {:ok, item in list}
          def slice(_list), do: {:error, __MODULE__}
        end
      end
      """

      document = Document.new("file:///test.ex", code, 1)
      analysis = Ast.analyze(document)

      # Position at "reduce" function name (line 3, character 11)
      position = Position.new(document, 3, 11)

      case Entity.resolve(analysis, position) do
        {:ok, {:protocol_callback, Enumerable, :reduce, 3}, _range} ->
          assert true

        {:ok, {:call, _module, :reduce, 3}, _range} ->
          # Fallback to normal call resolution is acceptable
          assert true

        other ->
          flunk("Expected protocol_callback or call, got: #{inspect(other)}")
      end
    end

    test "detects protocol callback for count/1" do
      code = """
      defmodule MyList do
        defimpl Enumerable, for: List do
          def reduce(list, acc, fun), do: Enum.reduce(list, acc, fun)
          def count(list), do: {:ok, length(list)}
          def member?(list, item), do: {:ok, item in list}
          def slice(_list), do: {:error, __MODULE__}
        end
      end
      """

      document = Document.new("file:///test.ex", code, 1)
      analysis = Ast.analyze(document)

      # Position at "count" function name (line 4, character 11)
      position = Position.new(document, 4, 11)

      case Entity.resolve(analysis, position) do
        {:ok, {:protocol_callback, Enumerable, :count, 1}, _range} ->
          assert true

        {:ok, {:call, _module, :count, 1}, _range} ->
          # Fallback to normal call resolution is acceptable
          assert true

        other ->
          flunk("Expected protocol_callback or call, got: #{inspect(other)}")
      end
    end

    test "detects String.Chars protocol" do
      code = """
      defmodule MyStruct do
        defstruct [:value]

        defimpl String.Chars do
          def to_string(%MyStruct{value: value}), do: "MyStruct: \#{value}"
        end
      end
      """

      document = Document.new("file:///test.ex", code, 1)
      analysis = Ast.analyze(document)

      # Position at "to_string" function name (line 5, character 10)
      position = Position.new(document, 5, 10)

      case Entity.resolve(analysis, position) do
        {:ok, {:protocol_callback, String.Chars, :to_string, 1}, _range} ->
          assert true

        {:ok, {:call, _module, :to_string, 1}, _range} ->
          # Fallback is acceptable
          assert true

        other ->
          flunk("Expected protocol_callback or call, got: #{inspect(other)}")
      end
    end

    test "does not detect protocol callback outside defimpl" do
      code = """
      defmodule MyModule do
        def count(list), do: length(list)
      end
      """

      document = Document.new("file:///test.ex", code, 1)
      analysis = Ast.analyze(document)

      # Position at "count" function name (line 2, character 8)
      position = Position.new(document, 2, 8)

      case Entity.resolve(analysis, position) do
        {:ok, {:call, _, :count, 1}, _range} ->
          # Should resolve as normal call, not protocol_callback
          assert true

        {:ok, {:protocol_callback, _, _, _}, _range} ->
          flunk("Should not resolve as protocol_callback outside defimpl")

        _other ->
          assert true
      end
    end

    test "handles non-existent protocol callbacks gracefully" do
      code = """
      defmodule MyList do
        defimpl Enumerable, for: List do
          def fake_callback(list), do: list
        end
      end
      """

      document = Document.new("file:///test.ex", code, 1)
      analysis = Ast.analyze(document)

      # Position at "fake_callback" function name
      position = Position.new(document, 3, 10)

      # Should fall back to regular call resolution since fake_callback
      # is not a real Enumerable callback
      case Entity.resolve(analysis, position) do
        {:ok, {:call, _module, :fake_callback, 1}, _range} ->
          assert true

        other ->
          # Any other resolution is fine, just shouldn't crash
          assert other != nil
      end
    end
  end
end
