# Comprehensive Plan: Jumping to Elixir Standard Library Source Code

**Feature:** Enable "Go to Definition" for Elixir and Erlang standard library modules and functions

**Issue Reference:** Lexical #772

**Priority:** Low (nice-to-have for learning/exploration, not critical for development)

**Complexity:** Low-Medium

---

## Executive Summary

Currently, the system uses a search index for user code and falls back to ElixirSense for unknown definitions. However, ElixirSense returns locations for stdlib code that can't be opened because the system doesn't know how to find the Elixir/Erlang installation paths. This plan outlines how to:

1. Detect when a module/function is from Elixir or Erlang stdlib
2. Dynamically discover installation paths
3. Map module names to source file paths
4. Handle edge cases and cross-platform differences

---

## PART 1: TEST PLAN

### 1.1 Understanding Current Test Patterns

**Files to review:**
- `apps/expert/test/engine/code_intelligence/definition_test.exs` - Main definition tests
- `apps/expert/test/expert/provider/handlers/go_to_definition_test.exs` - LSP handler tests
- `apps/forge/test/fixtures/navigations/` - Test fixtures

**Current test structure:**
- Uses `project(:navigations)` fixture
- Tests use `~q` sigil with `|` cursor marker
- Helper `definition/3` extracts cursor position and calls EngineApi
- Returns `{:ok, uri, decorated_line}` where decorated line shows range with `«»`
- Already has a skipped test for stdlib at line 381-391

**Key test utilities:**
- `Forge.Test.CodeSigil` - `~q` sigil for code with cursor
- `Forge.Test.CursorSupport` - `pop_cursor/1` to extract position
- `Forge.Test.RangeSupport` - `decorate/2` to show ranges with `«»`
- `Forge.Test.Fixtures` - `project/1` to load test projects

### 1.2 Test Case Categories

#### Category A: Elixir Core Modules (Kernel namespace)

**Test file location:** Add to `apps/expert/test/engine/code_intelligence/definition_test.exs`

**Test cases:**

1. **Basic module reference**
   ```elixir
   test "find Enum module definition" do
     subject = ~q[defmodule Test do
       Enu|m.map([], & &1)
     end]
     
     assert {:ok, uri, definition_line} = definition(project, subject)
     assert uri =~ "/lib/elixir/lib/enum.ex"
     assert definition_line =~ "defmodule «Enum» do"
   end
   ```

2. **Function call to core module**
   ```elixir
   test "find String.upcase/1 definition" do
     subject = ~q[String.upcas|e("hello")]
     
     assert {:ok, uri, definition_line} = definition(project, subject)
     assert uri =~ "/lib/elixir/lib/string.ex"
     assert definition_line =~ "def «upcase»"
   end
   ```

3. **Multiple arity functions**
   ```elixir
   test "find correct arity for String.slice/2 vs String.slice/3" do
     subject = ~q[String.slic|e("hello", 1, 2)]
     
     assert {:ok, uri, definition_line} = definition(project, subject)
     assert uri =~ "/lib/elixir/lib/string.ex"
     assert definition_line =~ "def «slice»(string, start, len)"
   end
   ```

4. **Commonly used modules**
   - `Enum` module and functions (`map/2`, `reduce/3`, `filter/2`)
   - `String` module and functions (`upcase/1`, `downcase/1`, `split/2`)
   - `Map` module and functions (`new/0`, `put/3`, `get/2`)
   - `List` module and functions (`first/1`, `flatten/1`)
   - `IO` module and functions (`puts/1`, `inspect/2`)
   - `Path` module and functions (`join/2`, `expand/1`)
   - `File` module and functions (`read/1`, `write/2`)

#### Category B: Elixir Special Forms (Kernel module)

**Test cases:**

5. **Kernel special forms and macros**
   ```elixir
   test "find def special form definition" do
     # This might be challenging - Kernel special forms
     # May need to skip or handle specially
   end
   
   test "find if macro definition" do
     subject = ~q[i|f true, do: :ok]
     
     # Should find in kernel.ex
     assert {:ok, uri, definition_line} = definition(project, subject)
     assert uri =~ "/lib/elixir/lib/kernel.ex"
   end
   ```

6. **Kernel imported functions**
   - `defmodule/2`, `def/2`, `defp/2`
   - `if/2`, `unless/2`, `case/2`
   - `raise/1`, `raise/2`
   - `length/1`, `hd/1`, `tl/1`

#### Category C: Elixir OTP Behaviors and Applications

**Test cases:**

7. **GenServer callbacks**
   ```elixir
   test "find GenServer.init callback definition" do
     subject = ~q[
       defmodule MyServer do
         use GenServer
         
         def init(args) do
           GenServer.ini|t(args)
         end
       end
     ]
     
     assert {:ok, uri, definition_line} = definition(project, subject)
     assert uri =~ "/lib/elixir/lib/gen_server.ex"
     assert definition_line =~ "defcallback «init»"
   end
   ```

8. **Supervisor**
   ```elixir
   test "find Supervisor module definition" do
     subject = ~q[Superviso|r.start_link([], strategy: :one_for_one)]
     
     assert {:ok, uri, _} = definition(project, subject)
     assert uri =~ "/lib/elixir/lib/supervisor.ex"
   end
   ```

9. **Application module**
   ```elixir
   test "find Application.get_env/2 definition" do
     subject = ~q[Application.get_en|v(:app, :key)]
     
     assert {:ok, uri, _} = definition(project, subject)
     assert uri =~ "/lib/elixir/lib/application.ex"
   end
   ```

10. **Other OTP behaviors**
    - `Task`
    - `Agent`
    - `DynamicSupervisor`
    - `Registry`

#### Category D: Elixir Protocols

**Test cases:**

11. **Protocol definitions**
    ```elixir
    test "find Enumerable protocol definition" do
      subject = ~q[
        defimpl Enumerabl|e, for: MyStruct do
          def count(_), do: {:error, __MODULE__}
        end
      ]
      
      assert {:ok, uri, _} = definition(project, subject)
      assert uri =~ "/lib/elixir/lib/enumerable.ex"
      assert definition_line =~ "defprotocol «Enumerable»"
    end
    ```

12. **Other protocols**
    - `String.Chars`
    - `Inspect`
    - `Collectable`
    - `Access`

#### Category E: Elixir Mix and ExUnit

**Test cases:**

13. **Mix module**
    ```elixir
    test "find Mix.Task module definition" do
      subject = ~q[
        defmodule Mix.Tasks.MyTask do
          use Mi|x.Task
        end
      ]
      
      assert {:ok, uri, _} = definition(project, subject)
      assert uri =~ "/lib/mix/lib/mix/task.ex"
    end
    ```

14. **ExUnit module**
    ```elixir
    test "find ExUnit.Case module definition" do
      subject = ~q[
        defmodule MyTest do
          use ExUnit.Cas|e
        end
      ]
      
      assert {:ok, uri, _} = definition(project, subject)
      assert uri =~ "/lib/ex_unit/lib/ex_unit/case.ex"
    end
    ```

#### Category F: Erlang Standard Library

**Test cases:**

15. **Erlang stdlib module**
    ```elixir
    test "find :lists module functions" do
      subject = ~q[:lists.revers|e([1, 2, 3])]
      
      assert {:ok, uri, definition_line} = definition(project, subject)
      assert uri =~ "/lib/stdlib-"
      assert uri =~ "/src/lists.erl"
      assert definition_line =~ "reverse"
    end
    ```

16. **Common Erlang modules**
    - `:lists` (reverse/1, map/2, foldl/3)
    - `:maps` (new/0, put/3, get/2)
    - `:erlang` (binary_to_atom/1, atom_to_binary/1)
    - `:ets` (new/2, insert/2, lookup/2)
    - `:gen_server` (call/2, cast/2)
    - `:timer` (sleep/1, send_after/2)

17. **Erlang kernel modules**
    ```elixir
    test "find :gen_server.call definition" do
      subject = ~q[:gen_server.cal|l(pid, :get_state)]
      
      assert {:ok, uri, _} = definition(project, subject)
      assert uri =~ "/lib/stdlib-"
      assert uri =~ "/src/gen_server.erl"
    end
    ```

#### Category G: Edge Cases and Error Handling

**Test cases:**

18. **Module not found**
    ```elixir
    test "returns nil for non-existent stdlib module" do
      subject = ~q[NonExistent.ModuleNam|e.foo()]
      
      # Should not crash, return nil or error
      assert {:ok, nil} = definition(project, subject)
    end
    ```

19. **Source file not available (precompiled installation)**
    ```elixir
    test "gracefully handles missing source files" do
      # May occur in Docker containers or minimal installations
      # Should return nil instead of crashing
    end
    ```

20. **Ambiguous definitions**
    ```elixir
    test "handles multiple function clauses" do
      subject = ~q[Enum.ma|p([1, 2], & &1 * 2)]
      
      # Should return the first clause or function head
      assert {:ok, uri, definition_line} = definition(project, subject)
    end
    ```

21. **Private functions**
    ```elixir
    # Stdlib private functions shouldn't be accessible
    # but if somehow referenced, should handle gracefully
    test "handles private stdlib functions gracefully" do
      # Implementation dependent on whether we index private fns
    end
    ```

22. **Macros vs functions**
    ```elixir
    test "distinguishes between macro and function definitions" do
      # defmacro vs def
      subject = ~q[Kernel.unles|s(false, do: :ok)]
      
      assert {:ok, uri, definition_line} = definition(project, subject)
      assert definition_line =~ "defmacro «unless»"
    end
    ```

23. **Aliased stdlib modules**
    ```elixir
    test "finds definition through alias" do
      subject = ~q[
        defmodule Test do
          alias Enum, as: E
          
          E.ma|p([], & &1)
        end
      ]
      
      assert {:ok, uri, _} = definition(project, subject)
      assert uri =~ "/lib/elixir/lib/enum.ex"
    end
    ```

24. **Imported stdlib functions**
    ```elixir
    test "finds definition through import" do
      subject = ~q[
        defmodule Test do
          import Enum, only: [map: 2]
          
          ma|p([], & &1)
        end
      ]
      
      assert {:ok, uri, _} = definition(project, subject)
      assert uri =~ "/lib/elixir/lib/enum.ex"
    end
    ```

#### Category H: Cross-Platform Considerations

**Test cases:**

25. **Path separators**
    ```elixir
    test "handles Windows path separators" do
      # Ensure C:\\ paths work correctly
    end
    ```

26. **Different installation methods**
    ```elixir
    # Test should pass regardless of:
    # - asdf
    # - Nix
    # - Homebrew
    # - System package manager
    # - Manual installation
    ```

### 1.3 Test Fixture Requirements

**No new fixtures needed** - Tests can use existing `navigations` project or create inline test modules.

**Optional:** Create a new fixture `navigations/lib/stdlib_user.ex`:
```elixir
defmodule StdlibUser do
  def use_enum do
    Enum.map([1, 2, 3], & &1 * 2)
  end
  
  def use_string do
    String.upcase("hello")
  end
  
  def use_erlang do
    :lists.reverse([1, 2, 3])
  end
end
```

### 1.4 Test Organization Strategy

**Recommended approach:**

1. **Update existing skipped test** (line 380-391 in definition_test.exs)
   - Remove `@tag :skip`
   - Update test to work with new implementation

2. **Add new describe block:**
   ```elixir
   describe "definition/2 for Elixir standard library" do
     # Category A-E tests here
   end
   
   describe "definition/2 for Erlang standard library" do
     # Category F tests here
   end
   
   describe "definition/2 stdlib edge cases" do
     # Category G-H tests here
   end
   ```

3. **Integration tests in go_to_definition_test.exs**
   - Add tests verifying LSP protocol compliance
   - Test that URIs are properly formatted
   - Test that positions are correct

### 1.5 Expected Behavior Specification

**Success criteria:**

1. **Jump succeeds** → Opens stdlib source file at correct location
2. **Source not found** → Returns `{:ok, nil}` without crashing
3. **Module not loaded** → Returns `{:ok, nil}` without crashing
4. **Performance** → No noticeable delay (< 100ms)
5. **Memory** → Minimal memory overhead (< 10MB for caching)

**Return value format:**
```elixir
{:ok, %Location{
  document: %Document{uri: "file:///path/to/stdlib/string.ex", ...},
  range: %Range{start: %Position{line: 123, character: 2}, ...}
}}
```

### 1.6 Test Execution Strategy

**Test order:**
1. Run all existing tests first → ensure no regressions
2. Enable skipped stdlib test → verify basic functionality
3. Add new test cases incrementally → one category at a time
4. Run on multiple platforms → CI matrix

**Performance benchmarks:**
```elixir
test "stdlib definition lookup is fast" do
  Benchee.run(%{
    "stdlib lookup" => fn -> 
      # Lookup should be < 100ms
    end
  })
end
```

---

## PART 2: IMPLEMENTATION PLAN

### 2.1 Discovery: Finding Elixir Installation Path

**Goal:** Dynamically locate Elixir and Erlang source directories

**Research findings:**
- `:code.lib_dir(:elixir)` returns Elixir installation lib directory
- `:code.lib_dir(:stdlib)` returns Erlang stdlib directory  
- `:code.lib_dir(:kernel)` returns Erlang kernel directory
- Source files are in `lib/elixir/lib/` subdirectory for Elixir
- Source files are in `src/` subdirectory for Erlang

**Implementation approach:**

```elixir
defmodule Engine.CodeIntelligence.StdlibPath do
  @moduledoc """
  Discovers and caches paths to Elixir and Erlang standard library source files.
  """
  
  @doc """
  Returns the source directory for Elixir stdlib.
  
  Examples:
    iex> elixir_source_dir()
    "/usr/local/lib/elixir/lib/elixir/lib"
  """
  def elixir_source_dir do
    :elixir
    |> :code.lib_dir()
    |> Path.join("lib/elixir/lib")
  end
  
  @doc """
  Returns the source directory for a specific Erlang application.
  
  Examples:
    iex> erlang_source_dir(:stdlib)
    "/usr/local/lib/erlang/lib/stdlib-6.2.2.1/src"
  """
  def erlang_source_dir(app) do
    app
    |> :code.lib_dir()
    |> Path.join("src")
  end
  
  @doc """
  Returns the source directory for Elixir application (Logger, Mix, ExUnit).
  
  Examples:
    iex> elixir_app_source_dir(:logger)
    "/usr/local/lib/elixir/lib/logger/lib"
  """
  def elixir_app_source_dir(app) do
    :elixir
    |> :code.lib_dir()
    |> Path.join("lib/#{app}/lib")
  end
  
  @doc """
  Checks if source directory exists and contains source files.
  """
  def source_dir_available?(dir) do
    File.dir?(dir) && has_source_files?(dir)
  end
  
  defp has_source_files?(dir) do
    case File.ls(dir) do
      {:ok, files} -> 
        Enum.any?(files, &(String.ends_with?(&1, ".ex") or String.ends_with?(&1, ".erl")))
      _ -> 
        false
    end
  end
end
```

**File location:** `apps/engine/lib/engine/code_intelligence/stdlib_path.ex`

### 2.2 Understanding Elixir Source Code Organization

**Elixir stdlib structure:**
```
/usr/local/lib/elixir/lib/
├── eex/lib/             # EEx templates
├── elixir/lib/          # Core Elixir modules
│   ├── access.ex
│   ├── agent.ex
│   ├── application.ex
│   ├── enum.ex
│   ├── file.ex
│   ├── gen_server.ex
│   ├── kernel.ex
│   ├── list.ex
│   ├── map.ex
│   ├── module.ex
│   ├── process.ex
│   ├── stream.ex
│   ├── string.ex
│   └── ...
├── ex_unit/lib/         # ExUnit testing
│   └── ex_unit/
│       ├── case.ex
│       └── ...
├── iex/lib/             # IEx REPL
├── logger/lib/          # Logger
│   └── logger/
│       ├── backends/
│       └── ...
└── mix/lib/             # Mix build tool
    └── mix/
        ├── task.ex
        └── ...
```

**Erlang stdlib structure:**
```
/usr/local/lib/erlang/lib/
├── stdlib-6.2.2.1/src/
│   ├── array.erl
│   ├── lists.erl
│   ├── maps.erl
│   ├── gen_server.erl
│   └── ...
└── kernel-10.2.7.1/src/
    ├── erlang.erl
    ├── code.erl
    └── ...
```

**Module to file mapping rules:**

1. **Elixir core modules** (Enum, String, Map, etc.)
   - Module: `Enum` → File: `{elixir_lib}/enum.ex`
   - Module: `String` → File: `{elixir_lib}/string.ex`
   - Pattern: `module |> to_string() |> Macro.underscore() <> ".ex"`

2. **Elixir nested modules** (Enum.OutOfBoundsError)
   - Module: `Enum.OutOfBoundsError` → File: `{elixir_lib}/enum.ex`
   - Pattern: Extract top-level module

3. **Elixir applications** (Logger, Mix, ExUnit)
   - Module: `Logger.Backends.Console` → File: `{elixir_lib}/logger/lib/logger/backends/console.ex`
   - Module: `Mix.Task` → File: `{elixir_lib}/mix/lib/mix/task.ex`
   - Module: `ExUnit.Case` → File: `{elixir_lib}/ex_unit/lib/ex_unit/case.ex`
   - Pattern: Detect app from module prefix, then map nested structure

4. **Erlang modules**
   - Module: `:lists` → File: `{stdlib_src}/lists.erl`
   - Module: `:gen_server` → File: `{stdlib_src}/gen_server.erl`
   - Module: `:erlang` → File: `{kernel_src}/erlang.erl`
   - Pattern: `module |> to_string() <> ".erl"`

### 2.3 Strategy: Detecting Stdlib vs User Modules

**Approach 1: Application detection** (Recommended)

```elixir
defmodule Engine.CodeIntelligence.StdlibDetector do
  @stdlib_apps [:elixir, :eex, :ex_unit, :iex, :logger, :mix]
  @erlang_apps [:kernel, :stdlib, :compiler, :crypto, :sasl, :mnesia]
  
  @doc """
  Determines if a module belongs to Elixir or Erlang stdlib.
  
  Returns:
    {:elixir, app} | {:erlang, app} | :user_code
  """
  def detect_stdlib_module(module) when is_atom(module) do
    case Application.get_application(module) do
      app when app in @stdlib_apps -> {:elixir, app}
      app when app in @erlang_apps -> {:erlang, app}
      _ -> :user_code
    end
  end
end
```

**Approach 2: Code loading check** (Fallback)

```elixir
def is_stdlib_module?(module) do
  case :code.which(module) do
    path when is_list(path) ->
      path_string = List.to_string(path)
      String.contains?(path_string, "/lib/elixir/") or
      String.contains?(path_string, "/lib/erlang/")
    _ ->
      false
  end
end
```

**File location:** `apps/engine/lib/engine/code_intelligence/stdlib_detector.ex`

### 2.4 Strategy: Locating Source Files

**Main resolver module:**

```elixir
defmodule Engine.CodeIntelligence.StdlibResolver do
  alias Engine.CodeIntelligence.StdlibPath
  alias Engine.CodeIntelligence.StdlibDetector
  
  @doc """
  Resolves a stdlib module to its source file path.
  
  Returns {:ok, file_path} or {:error, :not_found}
  """
  def resolve_source_file(module) when is_atom(module) do
    case StdlibDetector.detect_stdlib_module(module) do
      {:elixir, app} -> resolve_elixir_module(module, app)
      {:erlang, app} -> resolve_erlang_module(module, app)
      :user_code -> {:error, :not_stdlib}
    end
  end
  
  defp resolve_elixir_module(module, :elixir) do
    # Core Elixir module
    module_name = module |> to_string() |> String.trim_leading("Elixir.")
    file_name = Macro.underscore(module_name) <> ".ex"
    
    source_dir = StdlibPath.elixir_source_dir()
    file_path = Path.join(source_dir, file_name)
    
    if File.exists?(file_path) do
      {:ok, file_path}
    else
      # Try top-level module (for nested modules)
      top_level = module_name |> String.split(".") |> List.first()
      file_name = Macro.underscore(top_level) <> ".ex"
      file_path = Path.join(source_dir, file_name)
      
      if File.exists?(file_path) do
        {:ok, file_path}
      else
        {:error, :not_found}
      end
    end
  end
  
  defp resolve_elixir_module(module, app) when app in [:logger, :mix, :ex_unit, :eex, :iex] do
    # Elixir application module
    module_name = module |> to_string() |> String.trim_leading("Elixir.")
    
    # Remove app prefix (e.g., "Logger." from "Logger.Backends.Console")
    app_prefix = app |> to_string() |> Macro.camelize()
    relative_name = String.trim_leading(module_name, app_prefix <> ".")
    
    # Build path: logger/backends/console.ex
    path_parts = 
      relative_name
      |> String.split(".")
      |> Enum.map(&Macro.underscore/1)
    
    file_name = List.last(path_parts) <> ".ex"
    dir_parts = Enum.drop(path_parts, -1)
    
    source_dir = StdlibPath.elixir_app_source_dir(app)
    app_subdir = Path.join([source_dir, to_string(app)] ++ dir_parts)
    file_path = Path.join(app_subdir, file_name)
    
    if File.exists?(file_path) do
      {:ok, file_path}
    else
      {:error, :not_found}
    end
  end
  
  defp resolve_erlang_module(module, app) do
    # Erlang module
    module_name = to_string(module)
    file_name = module_name <> ".erl"
    
    source_dir = StdlibPath.erlang_source_dir(app)
    file_path = Path.join(source_dir, file_name)
    
    if File.exists?(file_path) do
      {:ok, file_path}
    else
      {:error, :not_found}
    end
  end
end
```

**File location:** `apps/engine/lib/engine/code_intelligence/stdlib_resolver.ex`

### 2.5 Integration with Existing Definition Lookup

**Current flow:**
```
definition/2 
  → Entity.resolve 
  → fetch_definition 
  → Store.exact (search index) 
  → elixir_sense_definition (fallback)
```

**New flow:**
```
definition/2 
  → Entity.resolve 
  → fetch_definition 
  → Store.exact (search index)
  → stdlib_definition (NEW - check if stdlib)
  → elixir_sense_definition (fallback for other cases)
```

**Changes to `apps/engine/lib/engine/code_intelligence/definition.ex`:**

```elixir
defmodule Engine.CodeIntelligence.Definition do
  alias Engine.CodeIntelligence.StdlibDefinition  # NEW
  
  # ... existing code ...
  
  defp maybe_fallback_to_elixir_sense(resolved, locations, analysis, position) do
    case locations do
      [] ->
        Logger.info("No definition found for #{inspect(resolved)} with Indexer.")
        
        # NEW: Try stdlib before falling back to ElixirSense
        case stdlib_definition(resolved, analysis, position) do
          {:ok, location} when not is_nil(location) -> 
            {:ok, location}
          _ -> 
            elixir_sense_definition(analysis, position)
        end

      [location] ->
        {:ok, location}

      _ ->
        {:ok, locations}
    end
  end
  
  # NEW function
  defp stdlib_definition({:module, module}, _analysis, _position) when is_atom(module) do
    StdlibDefinition.find_module_definition(module)
  end
  
  defp stdlib_definition({:struct, module}, _analysis, _position) when is_atom(module) do
    StdlibDefinition.find_struct_definition(module)
  end
  
  defp stdlib_definition({:call, module, function, arity}, _analysis, _position) 
      when is_atom(module) do
    StdlibDefinition.find_function_definition(module, function, arity)
  end
  
  defp stdlib_definition(_, _, _), do: {:ok, nil}
  
  # ... rest of existing code ...
end
```

### 2.6 Core Implementation: Finding Definitions in Stdlib Files

**New module for stdlib definition finding:**

```elixir
defmodule Engine.CodeIntelligence.StdlibDefinition do
  @moduledoc """
  Finds definitions within Elixir and Erlang standard library source files.
  """
  
  alias Engine.CodeIntelligence.StdlibResolver
  alias Forge.Document
  alias Forge.Document.Location
  alias Forge.Document.Position
  alias Forge.Document.Range
  
  require Logger
  
  @doc """
  Finds the definition of a stdlib module.
  """
  def find_module_definition(module) when is_atom(module) do
    with {:ok, file_path} <- StdlibResolver.resolve_source_file(module),
         {:ok, document} <- open_stdlib_document(file_path),
         {:ok, line_number} <- find_module_definition_line(document, module) do
      position = Position.new(document, line_number, 0)
      range = Range.new(position, position)
      {:ok, Location.new(range, document)}
    else
      error ->
        Logger.debug("Could not find stdlib module definition for #{inspect(module)}: #{inspect(error)}")
        {:ok, nil}
    end
  end
  
  @doc """
  Finds the definition of a struct in a stdlib module.
  """
  def find_struct_definition(module) when is_atom(module) do
    with {:ok, file_path} <- StdlibResolver.resolve_source_file(module),
         {:ok, document} <- open_stdlib_document(file_path),
         {:ok, line_number} <- find_struct_line(document) do
      position = Position.new(document, line_number, 0)
      range = Range.new(position, position)
      {:ok, Location.new(range, document)}
    else
      _ -> {:ok, nil}
    end
  end
  
  @doc """
  Finds the definition of a function in a stdlib module.
  """
  def find_function_definition(module, function, arity) when is_atom(module) do
    with {:ok, file_path} <- StdlibResolver.resolve_source_file(module),
         {:ok, document} <- open_stdlib_document(file_path),
         {:ok, line_number} <- find_function_line(document, function, arity) do
      position = Position.new(document, line_number, 0)
      range = Range.new(position, position)
      {:ok, Location.new(range, document)}
    else
      _ -> {:ok, nil}
    end
  end
  
  # Opens a stdlib source file as a temporary document
  defp open_stdlib_document(file_path) do
    uri = Document.Path.ensure_uri(file_path)
    Document.Store.open_temporary(uri)
  end
  
  # Finds the line where a module is defined
  defp find_module_definition_line(document, module) do
    module_name = module |> to_string() |> String.trim_leading("Elixir.")
    content = Document.to_string(document)
    
    # Try different patterns
    patterns = [
      ~r/^defmodule\s+#{Regex.escape(module_name)}\s+do/m,
      ~r/^defprotocol\s+#{Regex.escape(module_name)}\s+do/m
    ]
    
    find_line_by_patterns(content, patterns)
  end
  
  # Finds the line where a struct is defined
  defp find_struct_line(document) do
    content = Document.to_string(document)
    pattern = ~r/^\s*defstruct\s+/m
    
    find_line_by_patterns(content, [pattern])
  end
  
  # Finds the line where a function is defined
  defp find_function_line(document, function, arity) do
    content = Document.to_string(document)
    
    # Try multiple patterns for Elixir functions
    elixir_patterns = [
      # def function(arg1, arg2)
      ~r/^\s*def\s+#{function}\s*\(/m,
      # defp function(arg1, arg2)  
      ~r/^\s*defp\s+#{function}\s*\(/m,
      # defmacro function(arg1, arg2)
      ~r/^\s*defmacro\s+#{function}\s*\(/m,
      # def function when ... (guards)
      ~r/^\s*def\s+#{function}\s+when/m,
      # defcallback function(...) :: ...
      ~r/^\s*defcallback\s+#{function}\s*\(/m
    ]
    
    # Try Erlang patterns if it's an .erl file
    erlang_patterns = [
      # function(Arg1, Arg2) ->
      ~r/^#{function}\s*\(/m,
      # -spec function(...) -> ...
      ~r/^-spec\s+#{function}\s*\(/m
    ]
    
    patterns = 
      if String.ends_with?(Document.to_string(document), ".erl") do
        erlang_patterns
      else
        elixir_patterns
      end
    
    # Find line matching pattern and arity
    case find_line_by_patterns(content, patterns) do
      {:ok, line} -> 
        # TODO: Verify arity matches
        {:ok, line}
      error -> 
        error
    end
  end
  
  # Helper to find line number by regex patterns
  defp find_line_by_patterns(content, patterns) do
    lines = String.split(content, "\n")
    
    result = 
      Enum.find_value(patterns, fn pattern ->
        Enum.find_index(lines, fn line ->
          String.match?(line, pattern)
        end)
      end)
    
    case result do
      nil -> {:error, :not_found}
      line_index -> {:ok, line_index + 1}  # 1-indexed
    end
  end
end
```

**File location:** `apps/engine/lib/engine/code_intelligence/stdlib_definition.ex`

### 2.7 Opening/Displaying Stdlib Files

**Considerations:**
- Stdlib files are **read-only** (should not be edited)
- Files are outside the project workspace
- Need proper URI formatting

**Approach:**

1. Use `Document.Store.open_temporary/1` (already supports external files)
2. Ensure URI is properly formatted with `file://` scheme
3. LSP client should handle opening read-only files

**No special handling needed** - existing document opening infrastructure supports this.

### 2.8 Caching Strategy

**Performance goal:** < 100ms for definition lookup

**Cache layers:**

1. **Installation paths** (cache in memory, never changes during session)
   ```elixir
   defmodule Engine.CodeIntelligence.StdlibCache do
     use Agent
     
     def start_link(_) do
       Agent.start_link(fn -> %{
         elixir_source_dir: nil,
         erlang_dirs: %{},
         module_files: %{}
       } end, name: __MODULE__)
     end
     
     def get_elixir_source_dir do
       Agent.get_and_update(__MODULE__, fn state ->
         case state.elixir_source_dir do
           nil ->
             dir = StdlibPath.elixir_source_dir()
             {dir, %{state | elixir_source_dir: dir}}
           dir ->
             {dir, state}
         end
       end)
     end
     
     def get_module_file(module) do
       Agent.get(__MODULE__, fn state ->
         Map.get(state.module_files, module)
       end)
     end
     
     def put_module_file(module, file_path) do
       Agent.update(__MODULE__, fn state ->
         put_in(state.module_files[module], file_path)
       end)
     end
   end
   ```

2. **Module to file mappings** (cache after first lookup)
   - Cache miss: ~50ms (file system lookup)
   - Cache hit: ~1ms (memory lookup)

3. **Definition line numbers** (optional, may not be needed)
   - Files don't change during session
   - Re-parse is fast enough (~10ms)

**File location:** `apps/engine/lib/engine/code_intelligence/stdlib_cache.ex`

**Start cache in Engine supervisor:**
```elixir
# apps/engine/lib/engine.ex
children = [
  # ... existing children ...
  Engine.CodeIntelligence.StdlibCache
]
```

### 2.9 Implementation Steps with Code Locations

**Step 1: Create stdlib path discovery module**
- File: `apps/engine/lib/engine/code_intelligence/stdlib_path.ex`
- Tests: `apps/engine/test/engine/code_intelligence/stdlib_path_test.exs`
- Priority: High
- Estimated time: 2 hours

**Step 2: Create stdlib detector module**
- File: `apps/engine/lib/engine/code_intelligence/stdlib_detector.ex`
- Tests: `apps/engine/test/engine/code_intelligence/stdlib_detector_test.exs`
- Priority: High
- Estimated time: 2 hours

**Step 3: Create stdlib resolver module**
- File: `apps/engine/lib/engine/code_intelligence/stdlib_resolver.ex`
- Tests: `apps/engine/test/engine/code_intelligence/stdlib_resolver_test.exs`
- Priority: High
- Estimated time: 4 hours

**Step 4: Create stdlib definition finder module**
- File: `apps/engine/lib/engine/code_intelligence/stdlib_definition.ex`
- Tests: `apps/engine/test/engine/code_intelligence/stdlib_definition_test.exs`
- Priority: High
- Estimated time: 6 hours

**Step 5: Create caching layer**
- File: `apps/engine/lib/engine/code_intelligence/stdlib_cache.ex`
- Tests: `apps/engine/test/engine/code_intelligence/stdlib_cache_test.exs`
- Priority: Medium
- Estimated time: 3 hours

**Step 6: Integrate with existing definition lookup**
- File: `apps/engine/lib/engine/code_intelligence/definition.ex` (modify)
- Tests: Update `apps/expert/test/engine/code_intelligence/definition_test.exs`
- Priority: High
- Estimated time: 4 hours

**Step 7: Add comprehensive tests**
- Files: Test files mentioned above
- Priority: High
- Estimated time: 8 hours

**Step 8: Documentation and polish**
- Update README
- Add module documentation
- Handle edge cases
- Priority: Low
- Estimated time: 2 hours

**Total estimated time: 31 hours**

### 2.10 Edge Cases and Gotchas

**1. Source files not available**
- **Scenario:** Docker containers, minimal installations, precompiled packages
- **Solution:** Gracefully return `{:ok, nil}` instead of crashing
- **Detection:** Check `File.exists?` before opening

**2. Nix installations**
- **Scenario:** Nix uses unique paths like `/nix/store/...`
- **Solution:** `:code.lib_dir` works correctly, no special handling needed
- **Note:** Source files ARE available in Nix (verified)

**3. Multiple Elixir versions**
- **Scenario:** asdf or other version managers
- **Solution:** Use runtime's Elixir path (from `:code.lib_dir`), not system Elixir
- **Detection:** Automatic - uses the Elixir that's running the project

**4. Erlang source files on Windows**
- **Scenario:** Different path separators, encoding issues
- **Solution:** Use `Path.join` instead of string concatenation
- **Testing:** Add Windows CI workflow

**5. Private functions in stdlib**
- **Scenario:** User hovers over private stdlib function (if somehow imported)
- **Solution:** Our regex will find them (they exist in source)
- **Note:** This is fine - they're in the source code

**6. Macro-generated functions**
- **Scenario:** Functions generated by `use` or other macros
- **Solution:** May not find definition (no source code)
- **Fallback:** ElixirSense might handle this

**7. Protocol implementations**
- **Scenario:** User jumps to protocol function in an implementation
- **Solution:** Should jump to protocol definition, not implementation
- **Note:** Our code handles protocol definitions correctly

**8. Kernel special forms**
- **Scenario:** `def`, `defmodule`, `if`, etc.
- **Solution:** These ARE in `kernel.ex` source
- **Note:** May be defined as macros

**9. Built-in Erlang functions (BIFs)**
- **Scenario:** `:erlang.+/2`, `:erlang.==/2`
- **Solution:** These are in `erlang.erl` source
- **Note:** May use operator syntax

**10. File encoding issues**
- **Scenario:** Non-UTF8 characters in source files
- **Solution:** Elixir source is UTF-8, Erlang mostly ASCII
- **Handling:** Document.Store should handle this

**11. Symbolic links**
- **Scenario:** Elixir installation uses symlinks
- **Solution:** `File.exists?` follows symlinks automatically
- **Note:** No special handling needed

**12. Module not loaded**
- **Scenario:** Module exists but not loaded in VM
- **Solution:** `Application.get_application/1` may return `nil`
- **Fallback:** Use `:code.which` to check if module exists

### 2.11 Performance Considerations

**Optimization strategies:**

1. **Lazy initialization**
   - Don't discover paths on startup
   - Discover on first stdlib lookup

2. **Caching**
   - Cache installation directories (never change)
   - Cache module → file mappings
   - Don't cache file contents (files are small, parsing is fast)

3. **Async operations**
   - File system operations are already async (BEAM handles this)
   - No special async handling needed

4. **Memory usage**
   - Cache size: ~1-10MB (path strings only)
   - Acceptable for typical project

5. **Benchmarking**
   - Target: < 100ms for first lookup
   - Target: < 10ms for cached lookup
   - Measure with Benchee

**Performance tests:**

```elixir
defmodule Engine.CodeIntelligence.StdlibPerformanceTest do
  use ExUnit.Case
  
  test "stdlib lookup is fast" do
    # First lookup (cache miss)
    {time_us, _result} = :timer.tc(fn ->
      StdlibDefinition.find_module_definition(String)
    end)
    
    assert time_us < 100_000, "First lookup took #{time_us}μs (should be < 100ms)"
    
    # Second lookup (cache hit)
    {time_us, _result} = :timer.tc(fn ->
      StdlibDefinition.find_module_definition(String)
    end)
    
    assert time_us < 10_000, "Cached lookup took #{time_us}μs (should be < 10ms)"
  end
end
```

### 2.12 Cross-Platform Support

**Platform differences:**

| Platform | Package Manager | Elixir Path Example | Notes |
|----------|----------------|---------------------|-------|
| macOS | Homebrew | `/usr/local/Cellar/elixir/1.17.3/lib/elixir` | Versioned |
| macOS | asdf | `~/.asdf/installs/elixir/1.17.3-otp-27/lib/elixir` | Version in path |
| Linux | apt/yum | `/usr/lib/elixir/lib/elixir` | System location |
| Linux | asdf | `~/.asdf/installs/elixir/1.17.3-otp-27/lib/elixir` | Same as macOS |
| Linux | Nix | `/nix/store/.../lib/elixir` | Immutable |
| Windows | Scoop | `C:\Users\...\scoop\apps\elixir\current` | Current symlink |
| Windows | Chocolatey | `C:\ProgramData\chocolatey\lib\elixir\lib\elixir` | System location |

**Solution:** Use `:code.lib_dir/1` - works on all platforms

**Path separators:**
- Use `Path.join/2` instead of string concatenation
- Use `File.exists?/1` which handles platform differences

**Line endings:**
- Elixir uses LF (`\n`)
- Erlang uses LF (`\n`)
- Windows Git may convert to CRLF
- **Solution:** `String.split(content, "\n")` handles both

**File permissions:**
- Stdlib files are typically world-readable
- No permission issues expected

**Testing strategy:**
- Run CI on Linux, macOS, and Windows
- Test with multiple installation methods (asdf, system)
- Mock file system in unit tests

### 2.13 Success Criteria

**Feature is complete when:**

1. ✅ User can jump to `Enum.map` definition
2. ✅ User can jump to `String.upcase` definition
3. ✅ User can jump to `GenServer` module definition
4. ✅ User can jump to `:lists.reverse` definition
5. ✅ User can jump to `Logger` module definition
6. ✅ User can jump to `ExUnit.Case` module definition
7. ✅ System gracefully handles missing source files
8. ✅ System doesn't crash on unknown modules
9. ✅ Performance is acceptable (< 100ms)
10. ✅ Works on Linux, macOS, and Windows
11. ✅ Works with asdf, Homebrew, Nix, system packages
12. ✅ All tests pass
13. ✅ Documentation is updated

**Non-goals (out of scope):**

- ❌ Jumping to definitions in dependencies (Hex packages)
- ❌ Jumping to definitions in OTP applications (not stdlib)
- ❌ Editing stdlib files (read-only)
- ❌ Showing stdlib function documentation (separate feature)
- ❌ Auto-completion for stdlib (separate feature)

---

## PART 3: IMPLEMENTATION SEQUENCE

### Phase 1: Foundation (High Priority)

**Goal:** Get basic stdlib detection and path resolution working

1. Create `StdlibPath` module with tests
2. Create `StdlibDetector` module with tests
3. Create `StdlibResolver` module with tests
4. Verify can resolve: `String`, `Enum`, `:lists`, `Logger.Backends.Console`

**Deliverable:** Can reliably find stdlib source files

### Phase 2: Definition Finding (High Priority)

**Goal:** Find specific definitions within stdlib files

1. Create `StdlibDefinition` module with tests
2. Implement module definition finding
3. Implement function definition finding
4. Implement struct definition finding
5. Test with various stdlib modules

**Deliverable:** Can find line numbers for definitions

### Phase 3: Integration (High Priority)

**Goal:** Integrate with existing definition lookup system

1. Modify `Engine.CodeIntelligence.Definition`
2. Add stdlib lookup before ElixirSense fallback
3. Update existing tests
4. Add new integration tests

**Deliverable:** Working end-to-end for basic cases

### Phase 4: Optimization (Medium Priority)

**Goal:** Make it fast and reliable

1. Create `StdlibCache` module
2. Add caching to path discovery
3. Add caching to module resolution
4. Performance testing and tuning

**Deliverable:** Fast, production-ready implementation

### Phase 5: Polish (Low Priority)

**Goal:** Handle edge cases and improve UX

1. Add comprehensive error handling
2. Add logging for debugging
3. Handle all edge cases
4. Cross-platform testing
5. Documentation

**Deliverable:** Robust, well-documented feature

---

## PART 4: RISK ASSESSMENT

### High Risk

1. **Source files not available in production environments**
   - Mitigation: Graceful fallback, clear documentation
   - Impact: Feature doesn't work, but doesn't break anything

2. **Performance degradation**
   - Mitigation: Caching, benchmarking, optimization
   - Impact: Slow editor response times

### Medium Risk

1. **Cross-platform path issues**
   - Mitigation: Use `Path` module, extensive testing
   - Impact: Feature doesn't work on some platforms

2. **Regex patterns don't match all definition styles**
   - Mitigation: Multiple patterns, fallback to ElixirSense
   - Impact: Some definitions not found

### Low Risk

1. **Module not loaded edge case**
   - Mitigation: Check if module exists before resolving
   - Impact: Minor - rarely occurs

2. **Memory usage from caching**
   - Mitigation: Cache only necessary data, bounded cache size
   - Impact: Minimal - stdlib path strings are small

---

## PART 5: FUTURE ENHANCEMENTS

**Not part of this feature, but potential follow-ups:**

1. **Dependency source code navigation**
   - Jump to definitions in Hex packages
   - Requires downloading/extracting package sources

2. **Stdlib documentation inline**
   - Show stdlib function docs on hover
   - Already partially supported via ElixirSense

3. **Stdlib symbol search**
   - Fuzzy search across stdlib modules/functions
   - Add stdlib to workspace symbol search

4. **Source code annotations**
   - Mark stdlib code as read-only
   - Add "View on GitHub" link

5. **OTP application source navigation**
   - Jump to definitions in OTP apps (not stdlib)
   - Similar approach to this feature

---

## APPENDIX A: File Structure

```
apps/engine/lib/engine/code_intelligence/
├── definition.ex              # MODIFY: Add stdlib lookup
├── entity.ex                  # NO CHANGE
├── stdlib_cache.ex            # NEW: Caching layer
├── stdlib_definition.ex       # NEW: Find definitions in files
├── stdlib_detector.ex         # NEW: Detect stdlib modules
├── stdlib_path.ex             # NEW: Path discovery
└── stdlib_resolver.ex         # NEW: Module to file mapping

apps/engine/test/engine/code_intelligence/
├── definition_test.exs        # MODIFY: Add stdlib tests
├── stdlib_cache_test.exs      # NEW
├── stdlib_definition_test.exs # NEW
├── stdlib_detector_test.exs   # NEW
├── stdlib_path_test.exs       # NEW
└── stdlib_resolver_test.exs   # NEW

apps/expert/test/engine/code_intelligence/
└── definition_test.exs        # MODIFY: Enable skipped test

apps/expert/test/expert/provider/handlers/
└── go_to_definition_test.exs  # MODIFY: Add stdlib tests
```

---

## APPENDIX B: Example Test Output

```
Testing go to String.upcase definition...

  ✓ Opens file: file:///nix/store/.../lib/elixir/lib/string.ex
  ✓ Cursor at line 156, column 6
  ✓ Highlighted range: def «upcase»(string, mode \\ :default)
  ✓ Time: 15ms (cached)

Testing go to :lists.reverse definition...

  ✓ Opens file: file:///usr/lib/erlang/lib/stdlib-6.2.2.1/src/lists.erl
  ✓ Cursor at line 89
  ✓ Highlighted range: «reverse»(L) ->
  ✓ Time: 45ms (uncached)

Testing go to Logger.Backends.Console definition...

  ✓ Opens file: file:///.../lib/elixir/lib/logger/lib/logger/backends/console.ex
  ✓ Cursor at line 1
  ✓ Highlighted range: defmodule «Logger.Backends.Console» do
  ✓ Time: 8ms (cached)
```

---

## APPENDIX C: Key Code Snippets

**Detection example:**
```elixir
iex> StdlibDetector.detect_stdlib_module(String)
{:elixir, :elixir}

iex> StdlibDetector.detect_stdlib_module(Logger)
{:elixir, :logger}

iex> StdlibDetector.detect_stdlib_module(:lists)
{:erlang, :stdlib}

iex> StdlibDetector.detect_stdlib_module(MyApp.MyModule)
:user_code
```

**Resolution example:**
```elixir
iex> StdlibResolver.resolve_source_file(String)
{:ok, "/usr/local/lib/elixir/lib/elixir/lib/string.ex"}

iex> StdlibResolver.resolve_source_file(Logger.Backends.Console)
{:ok, "/usr/local/lib/elixir/lib/logger/lib/logger/backends/console.ex"}

iex> StdlibResolver.resolve_source_file(:lists)
{:ok, "/usr/lib/erlang/lib/stdlib-6.2.2.1/src/lists.erl"}
```

**Definition finding example:**
```elixir
iex> StdlibDefinition.find_function_definition(String, :upcase, 1)
{:ok, %Location{
  document: %Document{uri: "file:///.../string.ex"},
  range: %Range{start: %Position{line: 156, character: 6}, ...}
}}
```

---

## APPENDIX D: Configuration Options

**Future configuration (not part of initial implementation):**

```elixir
# config/config.exs
config :expert, :stdlib_navigation,
  enabled: true,
  cache_enabled: true,
  cache_ttl: :infinity,
  fallback_to_github: false  # Future: link to GitHub if source not found
```

---

## END OF PLAN

This comprehensive plan provides:
- ✅ Detailed test cases with expected behavior
- ✅ Implementation strategy with code examples
- ✅ File locations and module organization
- ✅ Edge case handling
- ✅ Performance considerations
- ✅ Cross-platform support
- ✅ Risk assessment
- ✅ Success criteria
- ✅ Implementation sequence

**Estimated total effort:** 31 hours (including testing and documentation)

**Recommended approach:** Implement in phases, starting with Phase 1 (Foundation)
