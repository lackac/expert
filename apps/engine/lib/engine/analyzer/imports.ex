defmodule Engine.Analyzer.Imports do
  alias Engine.Analyzer.Aliases
  alias Engine.Module.Loader
  alias Forge.Ast.Analysis
  alias Forge.Ast.Analysis.Import
  alias Forge.Ast.Analysis.Scope
  alias Forge.Document.Position
  alias Forge.Document.Range
  alias Forge.ProcessCache

  @spec at(Analysis.t(), Position.t()) :: [Scope.import_mfa()]
  def at(%Analysis{} = analysis, %Position{} = position) do
    case Analysis.scopes_at(analysis, position) do
      [%Scope{} = scope | _] ->
        imports(scope, position)

      _ ->
        []
    end
  end

  @spec imports(Scope.t(), Scope.scope_position()) :: [Scope.import_mfa()]
  def imports(%Scope{} = scope, position \\ :end) do
    scope
    |> import_map(position)
    |> Map.values()
    |> List.flatten()
  end

  defp import_map(%Scope{} = scope, position) do
    end_line = Scope.end_line(scope, position)

    use_imports = imports_from_uses(scope, end_line)

    (kernel_imports(scope) ++ scope.imports ++ use_imports)
    # sorting by line ensures that imports on later lines
    # override imports on earlier lines
    |> Enum.sort_by(& &1.range.start.line)
    |> Enum.take_while(&(&1.range.start.line <= end_line))
    |> Enum.reduce(%{}, fn %Import{} = import, current_imports ->
      apply_to_scope(import, scope, current_imports)
    end)
  end

  defp apply_to_scope(%Import{} = import, current_scope, %{} = current_imports) do
    import_module = Aliases.resolve_at(current_scope, import.module, import.range.start.line)

    functions = mfas_for(import_module, :functions)
    macros = mfas_for(import_module, :macros)

    case import.selector do
      :all ->
        Map.put(current_imports, import_module, functions ++ macros)

      [only: :functions] ->
        Map.put(current_imports, import_module, functions)

      [only: :macros] ->
        Map.put(current_imports, import_module, macros)

      [only: :sigils] ->
        sigils = mfas_for(import_module, :sigils)
        Map.put(current_imports, import_module, sigils)

      [only: functions_to_import] ->
        functions_to_import = function_and_arity_to_mfa(import_module, functions_to_import)
        Map.put(current_imports, import_module, functions_to_import)

      [except: functions_to_except] ->
        # This one is a little tricky. Imports using except have two cases.
        # In the first case, if the module hasn't been previously imported, we
        # collect all the functions in the current module and remove the ones in the
        # except clause.
        # If the module has been previously imported, we just remove the functions from
        # the except clause from those that have been previously imported.
        # See: https://hexdocs.pm/elixir/1.13.0/Kernel.SpecialForms.html#import/2-selector

        functions_to_except = function_and_arity_to_mfa(import_module, functions_to_except)

        if already_imported?(current_imports, import_module) do
          Map.update!(current_imports, import_module, fn old_imports ->
            old_imports -- functions_to_except
          end)
        else
          to_import = (functions ++ macros) -- functions_to_except
          Map.put(current_imports, import_module, to_import)
        end
    end
  end

  defp already_imported?(%{} = current_imports, imported_module) do
    case current_imports do
      %{^imported_module => [_ | _]} -> true
      _ -> false
    end
  end

  defp function_and_arity_to_mfa(current_module, fa_list) when is_list(fa_list) do
    Enum.map(fa_list, fn {function, arity} -> {current_module, function, arity} end)
  end

  defp mfas_for(current_module, type) do
    if Loader.ensure_loaded?(current_module) do
      fa_list = function_and_arities_for_module(current_module, type)

      function_and_arity_to_mfa(current_module, fa_list)
    else
      []
    end
  end

  defp function_and_arities_for_module(module, :sigils) do
    ProcessCache.trans({module, :info, :sigils}, fn ->
      for {name, arity} <- module.__info__(:functions),
          string_name = Atom.to_string(name),
          sigil?(string_name, arity) do
        {name, arity}
      end
    end)
  end

  defp function_and_arities_for_module(module, type) do
    ProcessCache.trans({module, :info, type}, fn ->
      type
      |> module.__info__()
      |> Enum.reject(fn {name, arity} ->
        string_name = Atom.to_string(name)
        String.starts_with?(string_name, "_") or sigil?(string_name, arity)
      end)
    end)
  end

  defp sigil?(string_name, arity) do
    String.starts_with?(string_name, "sigil_") and arity in [1, 2]
  end

  # Extract imports from `use` statements by expanding their __using__ macros
  defp imports_from_uses(%Scope{} = scope, end_line) do
    scope.uses
    |> Enum.filter(&(&1.range.start.line <= end_line))
    |> Enum.flat_map(fn use ->
      extract_imports_from_use(use, scope)
    end)
  end

  defp extract_imports_from_use(%{module: module_segments, opts: opts}, scope) do
    with {:ok, module} <- resolve_use_module(module_segments, scope),
         true <- Loader.ensure_loaded?(module),
         {:ok, quoted} <- expand_use_macro(module, opts) do
      # Extract import statements from the expanded quoted code
      {_, imports} =
        Macro.prewalk(quoted, [], fn
          {:import, _, [import_module | _]} = node, acc ->
            {node, [import_module | acc]}

          node, acc ->
            {node, acc}
        end)

      # Convert to Import structs
      imports
      |> Enum.map(fn import_ast ->
        module_segments =
          case import_ast do
            {:__aliases__, _, segments} -> segments
            module when is_atom(module) -> Module.split(module) |> Enum.map(&String.to_atom/1)
            _ -> []
          end

        if module_segments != [] do
          # Use the use statement's range for implicit imports
          Import.implicit(scope.range, module_segments)
        end
      end)
      |> Enum.reject(&is_nil/1)
    else
      _ -> []
    end
  end

  defp resolve_use_module(module_segments, scope) do
    module = Aliases.resolve_at(scope, module_segments, scope.range.start.line)
    {:ok, module}
  rescue
    _ -> :error
  end

  # Attempt to expand the __using__ macro
  # ISSUES:
  # 1. __using__ is a macro, not a function - can't call module.__using__([]) directly
  # 2. Macro.expand_once requires a proper compilation environment with all context
  # 3. This causes engine startup timeouts
  # 4. Runtime macro expansion is fundamentally different from compile-time
  defp expand_use_macro(module, opts) do
    # Try to create a minimal compilation environment
    env = %Macro.Env{
      module: module,
      file: "nofile",
      line: 1,
      function: nil,
      context: nil,
      requires: [],
      aliases: [],
      functions: [],
      macros: []
    }

    # Build a quoted use expression
    use_expr =
      if opts == [] do
        quote do
          use unquote(module)
        end
      else
        quote do
          use unquote(module), unquote(opts)
        end
      end

    # Try to expand the use macro
    # NOTE: This approach doesn't work because:
    # - It requires full compilation context
    # - Causes timeouts during engine initialization
    # - Runtime expansion != compile-time expansion
    try do
      expanded = Macro.expand_once(use_expr, env)
      {:ok, expanded}
    rescue
      _ -> :error
    end
  end

  defp kernel_imports(%Scope{} = scope) do
    start_pos = scope.range.start
    range = Range.new(start_pos, start_pos)

    [
      Import.implicit(range, [:Kernel]),
      Import.implicit(range, [:Kernel, :SpecialForms])
    ]
  end
end
