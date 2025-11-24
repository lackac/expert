defmodule Engine.StdlibResolver do
  @moduledoc """
  Resolves stdlib module names to their source file paths.

  This module maps Elixir and Erlang standard library modules to their
  corresponding source file locations on disk.
  """

  alias Engine.StdlibDetector
  alias Engine.StdlibPath

  require Logger

  @doc """
  Resolves a stdlib module to its source file path.

  Returns `{:ok, file_path}` if found, `{:error, reason}` otherwise.

  ## Examples

      iex> resolve_source_file(String)
      {:ok, "/usr/local/lib/elixir/lib/string.ex"}

      iex> resolve_source_file(Logger)
      {:ok, "/usr/local/lib/elixir/lib/logger/lib/logger.ex"}

      iex> resolve_source_file(:lists)
      {:ok, "/usr/lib/erlang/lib/stdlib-6.2.2.1/src/lists.erl"}

  """
  def resolve_source_file(module) when is_atom(module) do
    case StdlibDetector.detect_stdlib_module(module) do
      {:elixir, :elixir} ->
        resolve_elixir_core_module(module)

      {:elixir, app} when app in [:logger, :mix, :ex_unit, :eex, :iex] ->
        resolve_elixir_app_module(module, app)

      {:erlang, app} ->
        resolve_erlang_module(module, app)

      :user_code ->
        {:error, :not_stdlib}
    end
  end

  # Resolves Elixir core modules (Enum, String, Map, etc.)
  defp resolve_elixir_core_module(module) do
    source_dir = StdlibPath.elixir_source_dir()

    if source_dir do
      module_name = module |> to_string() |> String.trim_leading("Elixir.")
      file_name = Macro.underscore(module_name) <> ".ex"
      file_path = Path.join(source_dir, file_name)

      if File.exists?(file_path) do
        {:ok, file_path}
      else
        # Try top-level module (for nested modules like Enum.OutOfBoundsError)
        try_top_level_module(source_dir, module_name)
      end
    else
      {:error, :source_dir_not_found}
    end
  end

  defp try_top_level_module(source_dir, module_name) do
    top_level = module_name |> String.split(".") |> List.first()
    file_name = Macro.underscore(top_level) <> ".ex"
    file_path = Path.join(source_dir, file_name)

    if File.exists?(file_path) do
      {:ok, file_path}
    else
      {:error, :not_found}
    end
  end

  # Resolves Elixir application modules (Logger, Mix, ExUnit, etc.)
  defp resolve_elixir_app_module(module, app) do
    source_dir = StdlibPath.elixir_app_source_dir(app)

    if source_dir do
      module_name = module |> to_string() |> String.trim_leading("Elixir.")

      # Try direct path mapping
      relative_path = module_name_to_path(module_name)
      file_path = Path.join(source_dir, relative_path)

      if File.exists?(file_path) do
        {:ok, file_path}
      else
        # Try with app subdirectory (e.g., logger/lib/logger/backends/console.ex)
        app_subdir_path = Path.join([source_dir, to_string(app), relative_path])

        if File.exists?(app_subdir_path) do
          {:ok, app_subdir_path}
        else
          Logger.debug(
            "Could not find source file for #{module} at #{file_path} or #{app_subdir_path}"
          )

          {:error, :not_found}
        end
      end
    else
      {:error, :source_dir_not_found}
    end
  end

  # Converts module name to path: "Logger.Backends.Console" -> "logger/backends/console.ex"
  defp module_name_to_path(module_name) do
    module_name
    |> String.split(".")
    |> Enum.map(&Macro.underscore/1)
    |> Path.join()
    |> Kernel.<>(".ex")
  end

  # Resolves Erlang modules (:lists, :maps, etc.)
  defp resolve_erlang_module(module, app) do
    source_dir = StdlibPath.erlang_source_dir(app)

    if source_dir do
      module_name = to_string(module)
      file_name = module_name <> ".erl"
      file_path = Path.join(source_dir, file_name)

      if File.exists?(file_path) do
        {:ok, file_path}
      else
        {:error, :not_found}
      end
    else
      {:error, :source_dir_not_found}
    end
  end
end
