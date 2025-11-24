defmodule Engine.CodeIntelligence.StructFieldLocator do
  @moduledoc """
  Locates the precise definition location of a struct field within a defstruct declaration.

  Handles various defstruct formats:
  - Simple list: `defstruct [:name, :age]`
  - Keyword list: `defstruct [name: nil, age: 0]`
  - Mixed: `defstruct [:name, age: 0]`
  - Multi-line defstruct declarations
  """

  alias Engine.Search.Store
  alias Forge.Ast
  alias Forge.Document
  alias Forge.Document.Location
  alias Forge.Document.Position
  alias Forge.Document.Range
  alias Forge.Formats
  alias Forge.Search.Indexer.Entry

  require Logger

  @doc """
  Finds the location of a specific field in a struct definition.

  ## Parameters
  - `struct_module`: The module that defines the struct
  - `field_name`: The atom name of the field to locate

  ## Returns
  - `{:ok, Location.t()}` - The precise location of the field definition
  - `{:error, term()}` - If the struct or field cannot be found
  """
  @spec locate(module(), atom()) :: {:ok, Location.t()} | {:error, term()}
  def locate(struct_module, field_name) when is_atom(struct_module) and is_atom(field_name) do
    module_string = Formats.module(struct_module)

    with {:ok, entries} <- Store.exact(module_string, type: :struct, subtype: :definition),
         {:ok, entry} <- find_struct_entry(entries),
         {:ok, document} <- open_document(entry),
         {:ok, field_range} <- find_field_in_defstruct(document, entry, field_name) do
      {:ok, Location.new(field_range, document)}
    else
      {:error, _} = error ->
        Logger.debug(
          "Could not locate field #{field_name} in #{module_string}: #{inspect(error)}"
        )

        error

      :error ->
        {:error, :not_found}
    end
  end

  # Finds the first struct entry from the list
  defp find_struct_entry([entry | _rest]), do: {:ok, entry}
  defp find_struct_entry([]), do: {:error, :no_struct_entry}

  # Opens the document for the struct definition
  defp open_document(%Entry{path: path}) do
    uri = Document.Path.ensure_uri(path)
    Document.Store.open_temporary(uri)
  end

  # Finds the field within the defstruct AST node
  defp find_field_in_defstruct(%Document{} = document, %Entry{range: range}, field_name) do
    with {:ok, position} <- get_defstruct_position(document, range),
         {:ok, zipper} <- Ast.zipper_at(document, position),
         {:ok, field_range} <- locate_field_in_ast(zipper, field_name, document) do
      {:ok, field_range}
    end
  end

  # Gets a position within the defstruct node
  defp get_defstruct_position(%Document{} = _document, %Range{} = range) do
    {:ok, range.start}
  end

  # Locates the field within the defstruct AST
  defp locate_field_in_ast(zipper, field_name, document) do
    # Find the defstruct node
    case find_defstruct_node(zipper) do
      {:ok, defstruct_zipper} ->
        # Extract the fields list from defstruct
        case extract_fields_list(defstruct_zipper) do
          {:ok, fields_ast} ->
            find_field_in_list(fields_ast, field_name, document)

          :error ->
            {:error, :no_fields_list}
        end

      :error ->
        {:error, :not_in_defstruct}
    end
  end

  # Finds the defstruct node in the AST
  defp find_defstruct_node(zipper) do
    # Navigate up to find the defstruct node
    case find_ancestor(zipper, fn node ->
           match?({:defstruct, _, _}, node)
         end) do
      nil -> :error
      defstruct_zipper -> {:ok, defstruct_zipper}
    end
  end

  # Finds an ancestor node matching the predicate
  defp find_ancestor(zipper, predicate) do
    cond do
      predicate.(zipper.node) -> zipper
      parent = Sourceror.Zipper.up(zipper) -> find_ancestor(parent, predicate)
      true -> nil
    end
  end

  # Extracts the fields list from a defstruct node
  defp extract_fields_list(%Sourceror.Zipper{node: {:defstruct, _, [fields_list]}}) do
    {:ok, fields_list}
  end

  defp extract_fields_list(_), do: :error

  # Finds a specific field in the fields list AST
  defp find_field_in_list(fields_ast, field_name, document) do
    case do_find_field(fields_ast, field_name, document) do
      {:ok, _range} = result -> result
      nil -> {:error, :field_not_found}
    end
  end

  # Recursively searches for the field in the AST
  defp do_find_field(ast, field_name, document) do
    Sourceror.prewalk(ast, nil, fn
      # Match atom field in list: :name
      {:__block__, meta, [^field_name]} = node, nil ->
        range = node_to_range(node, meta, document)
        {node, {:ok, range}}

      # Match keyword field: name: value
      {{:__block__, meta, [^field_name]}, _value}, nil ->
        # Return range for just the key part
        range = meta_to_range(meta, field_name, document)
        {{:__block__, meta, [field_name]}, {:ok, range}}

      # Match keyword field as tuple: {:name, value}
      {:{}, _, [{:__block__, meta, [^field_name]}, _value]}, nil ->
        range = meta_to_range(meta, field_name, document)
        {{:__block__, meta, [field_name]}, {:ok, range}}

      node, acc ->
        {node, acc}
    end)
    |> elem(1)
  end

  # Converts an AST node to a Range
  defp node_to_range(node, meta, document) do
    case Ast.Range.fetch(node, document) do
      {:ok, range} -> range
      :error -> meta_to_range(meta, nil, document)
    end
  end

  # Creates a range from metadata
  defp meta_to_range(meta, field_name, document) do
    line = Keyword.get(meta, :line, 1)
    column = Keyword.get(meta, :column, 1)

    start_pos = Position.new(document, line, column)

    # Calculate end position based on field name length
    end_column =
      if field_name do
        column + String.length(Atom.to_string(field_name))
      else
        column + 1
      end

    end_pos = Position.new(document, line, end_column)

    Range.new(start_pos, end_pos)
  end
end
