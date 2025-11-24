defmodule Engine.StdlibCache do
  @moduledoc """
  Caches stdlib path information for performance.

  This cache stores:
  - Elixir source directory path
  - Erlang source directory paths by app
  - Module to file path mappings

  Cache entries never expire during the session since stdlib paths don't change.
  """

  use Agent

  require Logger

  def start_link(_opts) do
    Agent.start_link(
      fn ->
        %{
          elixir_source_dir: nil,
          erlang_dirs: %{},
          elixir_app_dirs: %{},
          module_files: %{}
        }
      end,
      name: __MODULE__
    )
  end

  @doc """
  Gets the cached Elixir source directory, or computes and caches it.
  """
  def get_elixir_source_dir do
    Agent.get_and_update(__MODULE__, fn state ->
      case state.elixir_source_dir do
        nil ->
          dir = Engine.StdlibPath.elixir_source_dir()
          Logger.debug("Cached Elixir source dir: #{inspect(dir)}")
          {dir, %{state | elixir_source_dir: dir}}

        dir ->
          {dir, state}
      end
    end)
  end

  @doc """
  Gets the cached Erlang source directory for an app, or computes and caches it.
  """
  def get_erlang_source_dir(app) when is_atom(app) do
    Agent.get_and_update(__MODULE__, fn state ->
      case Map.get(state.erlang_dirs, app) do
        nil ->
          dir = Engine.StdlibPath.erlang_source_dir(app)
          Logger.debug("Cached Erlang source dir for #{app}: #{inspect(dir)}")
          {dir, put_in(state.erlang_dirs[app], dir)}

        dir ->
          {dir, state}
      end
    end)
  end

  @doc """
  Gets the cached Elixir app source directory, or computes and caches it.
  """
  def get_elixir_app_source_dir(app) when is_atom(app) do
    Agent.get_and_update(__MODULE__, fn state ->
      case Map.get(state.elixir_app_dirs, app) do
        nil ->
          dir = Engine.StdlibPath.elixir_app_source_dir(app)
          Logger.debug("Cached Elixir app source dir for #{app}: #{inspect(dir)}")
          {dir, put_in(state.elixir_app_dirs[app], dir)}

        dir ->
          {dir, state}
      end
    end)
  end

  @doc """
  Gets a cached module file path.
  """
  def get_module_file(module) when is_atom(module) do
    Agent.get(__MODULE__, fn state ->
      Map.get(state.module_files, module)
    end)
  end

  @doc """
  Caches a module file path.
  """
  def put_module_file(module, file_path) when is_atom(module) do
    Agent.update(__MODULE__, fn state ->
      put_in(state.module_files[module], file_path)
    end)
  end

  @doc """
  Clears the cache. Useful for testing.
  """
  def clear do
    Agent.update(__MODULE__, fn _state ->
      %{
        elixir_source_dir: nil,
        erlang_dirs: %{},
        elixir_app_dirs: %{},
        module_files: %{}
      }
    end)
  end
end
