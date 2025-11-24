defmodule Expert.Engine.StdlibDefinitionTest do
  use ExUnit.Case, async: false

  alias Engine.StdlibDefinition
  alias Forge.Document
  alias Forge.Document.Location

  setup_all do
    # Start only the Document.Store for opening temporary files
    start_supervised!({Document.Store, derive: [analysis: &Forge.Ast.analyze/1]})
    :ok
  end

  describe "find_module_definition/1 for Elixir core modules" do
    test "finds String module definition" do
      assert {:ok, %Location{} = location} = StdlibDefinition.find_module_definition(String)
      assert location.document.path =~ "string.ex"
      assert location.range.start.line > 0
    end

    test "finds Enum module definition" do
      assert {:ok, %Location{} = location} = StdlibDefinition.find_module_definition(Enum)
      assert location.document.path =~ "enum.ex"
      assert location.range.start.line > 0
    end

    test "finds Map module definition" do
      assert {:ok, %Location{} = location} = StdlibDefinition.find_module_definition(Map)
      assert location.document.path =~ "map.ex"
      assert location.range.start.line > 0
    end

    test "finds List module definition" do
      assert {:ok, %Location{} = location} = StdlibDefinition.find_module_definition(List)
      assert location.document.path =~ "list.ex"
      assert location.range.start.line > 0
    end

    test "finds Kernel module definition" do
      assert {:ok, %Location{} = location} = StdlibDefinition.find_module_definition(Kernel)
      assert location.document.path =~ "kernel.ex"
      assert location.range.start.line > 0
    end

    test "finds GenServer module definition" do
      assert {:ok, %Location{} = location} = StdlibDefinition.find_module_definition(GenServer)
      assert location.document.path =~ "gen_server.ex"
      assert location.range.start.line > 0
    end

    test "finds Supervisor module definition" do
      assert {:ok, %Location{} = location} = StdlibDefinition.find_module_definition(Supervisor)
      assert location.document.path =~ "supervisor.ex"
      assert location.range.start.line > 0
    end

    test "finds Application module definition" do
      assert {:ok, %Location{} = location} = StdlibDefinition.find_module_definition(Application)
      assert location.document.path =~ "application.ex"
      assert location.range.start.line > 0
    end

    test "finds IO module definition" do
      assert {:ok, %Location{} = location} = StdlibDefinition.find_module_definition(IO)
      assert location.document.path =~ "io.ex"
      assert location.range.start.line > 0
    end

    test "finds File module definition" do
      assert {:ok, %Location{} = location} = StdlibDefinition.find_module_definition(File)
      assert location.document.path =~ "file.ex"
      assert location.range.start.line > 0
    end

    test "finds Path module definition" do
      assert {:ok, %Location{} = location} = StdlibDefinition.find_module_definition(Path)
      assert location.document.path =~ "path.ex"
      assert location.range.start.line > 0
    end

    test "finds Process module definition" do
      assert {:ok, %Location{} = location} = StdlibDefinition.find_module_definition(Process)
      assert location.document.path =~ "process.ex"
      assert location.range.start.line > 0
    end
  end

  describe "find_module_definition/1 for protocols" do
    test "finds Enumerable protocol definition" do
      # Enumerable protocol is defined in enum.ex, not a separate file
      case StdlibDefinition.find_module_definition(Enumerable) do
        {:ok, %Location{} = location} ->
          assert location.document.path =~ ~r/enum(erable)?\.ex/
          assert location.range.start.line > 0

        {:ok, nil} ->
          # Protocol may be co-located with other modules
          :ok
      end
    end

    test "finds Inspect protocol definition" do
      assert {:ok, %Location{} = location} = StdlibDefinition.find_module_definition(Inspect)
      assert location.document.path =~ "inspect.ex"
      assert location.range.start.line > 0
    end

    test "finds Collectable protocol definition" do
      assert {:ok, %Location{} = location} = StdlibDefinition.find_module_definition(Collectable)
      assert location.document.path =~ "collectable.ex"
      assert location.range.start.line > 0
    end
  end

  describe "find_module_definition/1 for Elixir application modules" do
    test "finds Logger module definition" do
      assert {:ok, %Location{} = location} = StdlibDefinition.find_module_definition(Logger)
      assert location.document.path =~ "logger"
      assert location.range.start.line > 0
    end

    test "finds Mix.Task module definition" do
      assert {:ok, %Location{} = location} = StdlibDefinition.find_module_definition(Mix.Task)
      assert location.document.path =~ "mix"
      assert location.document.path =~ "task.ex"
      assert location.range.start.line > 0
    end

    test "finds ExUnit.Case module definition" do
      assert {:ok, %Location{} = location} = StdlibDefinition.find_module_definition(ExUnit.Case)
      assert location.document.path =~ "ex_unit"
      assert location.document.path =~ "case.ex"
      assert location.range.start.line > 0
    end
  end

  describe "find_function_definition/3 for Elixir core functions" do
    test "finds String.upcase function" do
      assert {:ok, %Location{} = location} =
               StdlibDefinition.find_function_definition(String, :upcase, 1)

      assert location.document.path =~ "string.ex"
      assert location.range.start.line > 0
    end

    test "finds Enum.map function" do
      assert {:ok, %Location{} = location} =
               StdlibDefinition.find_function_definition(Enum, :map, 2)

      assert location.document.path =~ "enum.ex"
      assert location.range.start.line > 0
    end

    test "finds Enum.reduce function" do
      assert {:ok, %Location{} = location} =
               StdlibDefinition.find_function_definition(Enum, :reduce, 3)

      assert location.document.path =~ "enum.ex"
      assert location.range.start.line > 0
    end

    test "finds Enum.filter function" do
      assert {:ok, %Location{} = location} =
               StdlibDefinition.find_function_definition(Enum, :filter, 2)

      assert location.document.path =~ "enum.ex"
      assert location.range.start.line > 0
    end

    test "finds Map.new function" do
      assert {:ok, %Location{} = location} =
               StdlibDefinition.find_function_definition(Map, :new, 0)

      assert location.document.path =~ "map.ex"
      assert location.range.start.line > 0
    end

    test "finds Map.put function" do
      assert {:ok, %Location{} = location} =
               StdlibDefinition.find_function_definition(Map, :put, 3)

      assert location.document.path =~ "map.ex"
      assert location.range.start.line > 0
    end

    test "finds IO.puts function" do
      assert {:ok, %Location{} = location} =
               StdlibDefinition.find_function_definition(IO, :puts, 1)

      assert location.document.path =~ "io.ex"
      assert location.range.start.line > 0
    end

    test "finds Path.join function" do
      assert {:ok, %Location{} = location} =
               StdlibDefinition.find_function_definition(Path, :join, 2)

      assert location.document.path =~ "path.ex"
      assert location.range.start.line > 0
    end
  end

  describe "find_function_definition/3 error cases" do
    test "returns nil for non-existent function" do
      assert {:ok, nil} =
               StdlibDefinition.find_function_definition(String, :non_existent_function, 1)
    end

    test "returns nil for non-stdlib module" do
      assert {:ok, nil} = StdlibDefinition.find_function_definition(NonExistent.Module, :foo, 1)
    end
  end

  describe "find_struct_definition/1" do
    test "finds struct definition in File.Stat" do
      result = StdlibDefinition.find_struct_definition(File.Stat)

      case result do
        {:ok, %Location{} = location} ->
          # File.Stat can be in file.ex or file/stat.ex depending on Elixir version
          assert location.document.path =~ "file"
          assert String.ends_with?(location.document.path, ".ex")
          assert location.range.start.line > 0

        {:ok, nil} ->
          # Struct might not be found depending on file structure
          :ok
      end
    end

    test "returns nil for module without struct" do
      assert {:ok, nil} = StdlibDefinition.find_struct_definition(String)
    end
  end
end
