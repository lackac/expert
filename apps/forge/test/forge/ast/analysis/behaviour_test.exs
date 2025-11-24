defmodule Forge.Ast.Analysis.BehaviourTest do
  use ExUnit.Case, async: true

  alias Forge.Ast
  alias Forge.Document

  describe "behaviour tracking" do
    test "tracks @behaviour declaration" do
      code = """
      defmodule MyImpl do
        @behaviour GenServer

        def init(arg), do: {:ok, arg}
      end
      """

      doc = Document.new("file:///test.ex", code, 1)
      analysis = Ast.analyze(doc)

      scope = Enum.find(analysis.scopes, fn s -> s.module == [:MyImpl] end)
      assert scope != nil
      assert length(scope.behaviours) == 1

      [behaviour] = scope.behaviours
      assert behaviour.module == GenServer
      assert behaviour.range != nil
    end

    test "tracks multiple @behaviour declarations" do
      code = """
      defmodule MyImpl do
        @behaviour GenServer
        @behaviour Supervisor

        def init(arg), do: {:ok, arg}
      end
      """

      doc = Document.new("file:///test.ex", code, 1)
      analysis = Ast.analyze(doc)

      scope =
        Enum.find(analysis.scopes, fn s -> s.module == [:MyImpl] and length(s.behaviours) > 0 end)

      assert scope != nil
      assert length(scope.behaviours) == 2

      modules = Enum.map(scope.behaviours, & &1.module)
      assert GenServer in modules
      assert Supervisor in modules
    end

    test "handles aliased behaviour" do
      code = """
      defmodule MyImpl do
        alias GenServer, as: GS
        @behaviour GS

        def init(arg), do: {:ok, arg}
      end
      """

      doc = Document.new("file:///test.ex", code, 1)
      analysis = Ast.analyze(doc)

      scope =
        Enum.find(analysis.scopes, fn s -> s.module == [:MyImpl] and length(s.behaviours) > 0 end)

      assert scope != nil
      assert length(scope.behaviours) == 1

      [behaviour] = scope.behaviours
      assert behaviour.module == GenServer
    end

    test "handles nested module behaviour" do
      code = """
      defmodule Parent do
        defmodule Child do
          @behaviour GenServer

          def init(arg), do: {:ok, arg}
        end
      end
      """

      doc = Document.new("file:///test.ex", code, 1)
      analysis = Ast.analyze(doc)

      scope =
        Enum.find(analysis.scopes, fn s ->
          s.module == [:Parent, :Child] and length(s.behaviours) > 0
        end)

      assert scope != nil
      assert length(scope.behaviours) == 1

      [behaviour] = scope.behaviours
      assert behaviour.module == GenServer
    end

    test "does not track behaviours in outer scope" do
      code = """
      defmodule Parent do
        defmodule Child do
          @behaviour GenServer
        end

        # This scope should not have GenServer behaviour
        def some_func, do: :ok
      end
      """

      doc = Document.new("file:///test.ex", code, 1)
      analysis = Ast.analyze(doc)

      # Parent module scope should not have the behaviour
      parent_scopes = Enum.filter(analysis.scopes, fn s -> s.module == [:Parent] end)

      # Find the scope that's not the Child module
      parent_only_scopes =
        Enum.reject(parent_scopes, fn s ->
          Enum.any?(s.aliases, fn a -> a.as == :__MODULE__ and a.module == [:Parent, :Child] end)
        end)

      Enum.each(parent_only_scopes, fn scope ->
        assert length(scope.behaviours) == 0 or
                 Enum.all?(scope.behaviours, fn b -> b.module != GenServer end)
      end)
    end
  end
end
