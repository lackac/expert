defmodule Engine.StdlibDefinition do
  @moduledoc """
  Finds definitions within Elixir and Erlang standard library source files.

  This module locates specific module, function, and struct definitions
  within stdlib source files and returns their locations.
  """

  alias Engine.StdlibResolver
  alias Forge.Document
  alias Forge.Document.Location
  alias Forge.Document.Position
  alias Forge.Document.Range

  require Logger

  @doc """
  Finds the definition of a stdlib module.

  Returns `{:ok, Location.t()}` if found, `{:ok, nil}` if not found or error.
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
        Logger.debug(
          "Could not find stdlib module definition for #{inspect(module)}: #{inspect(error)}"
        )

        {:ok, nil}
    end
  end

  @doc """
  Finds the definition of a struct in a stdlib module.

  Returns `{:ok, Location.t()}` if found, `{:ok, nil}` if not found or error.
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

  Returns `{:ok, Location.t()}` if found, `{:ok, nil}` if not found or error.
  """
  def find_function_definition(module, function, _arity)
      when is_atom(module) and is_atom(function) do
    with {:ok, file_path} <- StdlibResolver.resolve_source_file(module),
         {:ok, document} <- open_stdlib_document(file_path),
         {:ok, line_number} <- find_function_line(document, function) do
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
      ~r/^defprotocol\s+#{Regex.escape(module_name)}\s+do/m,
      ~r/^defexception\s+#{Regex.escape(module_name)}\s+do/m
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
  defp find_function_line(document, function) do
    content = Document.to_string(document)
    function_str = to_string(function)

    # Check if it's an Erlang file
    is_erlang = String.ends_with?(document.path, ".erl")

    patterns =
      if is_erlang do
        erlang_function_patterns(function_str)
      else
        elixir_function_patterns(function_str)
      end

    find_line_by_patterns(content, patterns)
  end

  defp elixir_function_patterns(function_str) do
    [
      # def function(args)
      ~r/^\s*def\s+#{Regex.escape(function_str)}\s*\(/m,
      # defp function(args)
      ~r/^\s*defp\s+#{Regex.escape(function_str)}\s*\(/m,
      # defmacro function(args)
      ~r/^\s*defmacro\s+#{Regex.escape(function_str)}\s*\(/m,
      # defmacrop function(args)
      ~r/^\s*defmacrop\s+#{Regex.escape(function_str)}\s*\(/m,
      # def function when guard
      ~r/^\s*def\s+#{Regex.escape(function_str)}\s+when/m,
      # defcallback function(args)
      ~r/^\s*defcallback\s+#{Regex.escape(function_str)}\s*\(/m,
      # defdelegate function
      ~r/^\s*defdelegate\s+#{Regex.escape(function_str)}\s*[\(,]/m
    ]
  end

  defp erlang_function_patterns(function_str) do
    [
      # function(Args) ->
      ~r/^#{Regex.escape(function_str)}\s*\(/m,
      # -spec function(Args) -> ReturnType
      ~r/^-spec\s+#{Regex.escape(function_str)}\s*\(/m
    ]
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
      # Return 1-indexed line number
      line_index -> {:ok, line_index + 1}
    end
  end
end
