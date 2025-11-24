defmodule Forge.Ast.Analysis.Behaviour do
  @moduledoc """
  Represents a behaviour declaration in a module.

  A behaviour is declared with `@behaviour ModuleName` and defines
  callbacks that implementing modules must provide.
  """

  alias Forge.Ast
  alias Forge.Document
  alias Forge.Document.Range

  defstruct [:module, :range]

  @type t :: %__MODULE__{
          module: module(),
          range: Range.t() | nil
        }

  @doc """
  Creates a new Behaviour struct for a behaviour declaration.
  """
  def new(%Document{} = document, ast, module) when is_list(module) do
    range = Ast.Range.get(ast, document)
    %__MODULE__{module: Module.concat(module), range: range}
  end
end
