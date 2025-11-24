defmodule Expert.Engine.CodeIntelligence.StructFieldDefinitionTest do
  alias Engine.Search
  alias Expert.EngineApi
  alias Expert.EngineNode
  alias Expert.EngineSupervisor
  alias Forge.Document

  import Forge.EngineApi.Messages
  import Forge.Test.CodeSigil
  import Forge.Test.CursorSupport
  import Forge.Test.Fixtures
  import Forge.Test.RangeSupport

  use ExUnit.Case, async: false

  defp with_referenced_file(%{project: project}) do
    uri =
      project
      |> file_path(Path.join("lib", "my_definition.ex"))
      |> Document.Path.ensure_uri()

    {:ok, _document} = Document.Store.open_temporary(uri)

    on_exit(fn ->
      :ok = Document.Store.close(uri)
    end)

    %{uri: uri}
  end

  defp subject_module_uri(project) do
    project
    |> file_path(Path.join("lib", "my_module.ex"))
    |> Document.Path.ensure_uri()
  end

  defp subject_module(project, content) do
    uri = subject_module_uri(project)

    with :ok <- Document.Store.open(uri, content, 1) do
      Document.Store.fetch(uri)
    end
  end

  setup_all do
    {:ok, _} = start_supervised({Forge.NodePortMapper, []})
    project = project(:navigations)
    start_supervised!({Document.Store, derive: [analysis: &Forge.Ast.analyze/1]})
    {:ok, _} = start_supervised({EngineSupervisor, project})
    {:ok, _, _} = EngineNode.start(project)

    EngineApi.register_listener(project, self(), [:all])
    EngineApi.schedule_compile(project, true)

    assert_receive project_compiled(), 5000
    assert_receive project_index_ready(), 5000

    %{project: project}
  end

  setup %{project: project} do
    uri = subject_module_uri(project)

    on_exit(fn ->
      :ok = Document.Store.close(uri)
    end)

    %{subject_uri: uri}
  end

  describe "struct field definition in existing fixture" do
    setup [:with_referenced_file]

    test "jump to simple field in MyDefinition", %{project: project, uri: referenced_uri} do
      subject_module = ~q[
        defmodule UsesMyDefinition do
          alias MyDefinition

          def test do
            %MyDefinition{fiel|d: "value"}
          end
        end
      ]

      assert {:ok, ^referenced_uri, definition_line} =
               definition(project, subject_module, referenced_uri)

      # The field should be found in the defstruct
      assert definition_line =~ ":field"
    end

    test "jump to keyword field in MyDefinition", %{project: project, uri: referenced_uri} do
      subject_module = ~q[
        defmodule UsesMyDefinition do
          alias MyDefinition

          def test do
            %MyDefinition{another_fiel|d: "test"}
          end
        end
      ]

      assert {:ok, ^referenced_uri, definition_line} =
               definition(project, subject_module, referenced_uri)

      assert definition_line =~ "another_field"
    end
  end

  defp definition(project, code, referenced_uri) do
    with {position, code} <- pop_cursor(code),
         {:ok, document} <- subject_module(project, code),
         :ok <- index(project, referenced_uri),
         {:ok, location} <- EngineApi.definition(project, document, position) do
      if is_list(location) do
        {:ok, Enum.map(location, &{&1.document.uri, decorate(&1.document, &1.range)})}
      else
        {:ok, location.document.uri, decorate(location.document, location.range)}
      end
    end
  end

  defp index(project, referenced_uri) do
    entries = do_index(referenced_uri)
    EngineApi.call(project, Search.Store, :replace, [entries])
  end

  defp do_index(referenced_uri) do
    with {:ok, document} <- Document.Store.fetch(referenced_uri),
         {:ok, entries} <-
           Search.Indexer.Source.index(document.path, Document.to_string(document)) do
      entries
    end
  end
end
