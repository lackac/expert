defmodule Engine.StdlibPath do
  @moduledoc """
  Discovers and caches paths to Elixir and Erlang standard library source files.

  This module provides functions to locate the source directories for:
  - Elixir core modules (Enum, String, Map, etc.)
  - Elixir applications (Logger, Mix, ExUnit, etc.)
  - Erlang standard library modules (:lists, :maps, :gen_server, etc.)

  The paths are determined dynamically at runtime using `:code.lib_dir/1`,
  which works across different installation methods (asdf, Homebrew, Nix, etc.).
  """

  require Logger

  @doc """
  Returns the source directory for Elixir stdlib.

  ## Examples

      iex> elixir_source_dir()
      "/usr/local/lib/elixir/lib/elixir/lib"

  """
  def elixir_source_dir do
    try do
      :elixir
      |> :code.lib_dir()
      |> to_string()
      |> Path.join("lib")
    rescue
      error ->
        Logger.warning("Failed to get Elixir source directory: #{inspect(error)}")
        nil
    end
  end

  @doc """
  Returns the source directory for a specific Erlang application.

  ## Examples

      iex> erlang_source_dir(:stdlib)
      "/usr/local/lib/erlang/lib/stdlib-6.2.2.1/src"

  """
  def erlang_source_dir(app) when is_atom(app) do
    try do
      app
      |> :code.lib_dir()
      |> to_string()
      |> Path.join("src")
    rescue
      error ->
        Logger.debug("Failed to get Erlang source directory for #{app}: #{inspect(error)}")
        nil
    end
  end

  @doc """
  Returns the source directory for an Elixir application (Logger, Mix, ExUnit).

  ## Examples

      iex> elixir_app_source_dir(:logger)
      "/usr/local/lib/elixir/lib/logger/lib"

  """
  def elixir_app_source_dir(app) when is_atom(app) do
    try do
      app
      |> :code.lib_dir()
      |> to_string()
      |> Path.join("lib")
    rescue
      error ->
        Logger.debug("Failed to get Elixir app source directory for #{app}: #{inspect(error)}")
        nil
    end
  end

  @doc """
  Checks if source directory exists and contains source files.
  """
  def source_dir_available?(nil), do: false

  def source_dir_available?(dir) do
    File.dir?(dir) && has_source_files?(dir)
  end

  defp has_source_files?(dir) do
    case File.ls(dir) do
      {:ok, files} ->
        Enum.any?(files, fn file ->
          String.ends_with?(file, ".ex") or String.ends_with?(file, ".erl")
        end)

      _ ->
        false
    end
  end
end
