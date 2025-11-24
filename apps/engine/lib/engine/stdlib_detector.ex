defmodule Engine.StdlibDetector do
  @moduledoc """
  Detects whether a module belongs to Elixir or Erlang standard library.

  This module determines if a given module is part of the standard library
  (either Elixir core, Elixir applications, or Erlang stdlib) versus user code.
  """

  @stdlib_apps [:elixir, :eex, :ex_unit, :iex, :logger, :mix]
  @erlang_apps [:kernel, :stdlib, :compiler, :crypto, :sasl, :mnesia, :ssl, :inets]

  @doc """
  Determines if a module belongs to Elixir or Erlang stdlib.

  Returns:
  - `{:elixir, app}` if the module is from an Elixir stdlib app
  - `{:erlang, app}` if the module is from an Erlang stdlib app
  - `:user_code` if the module is user code or not recognized

  ## Examples

      iex> detect_stdlib_module(String)
      {:elixir, :elixir}

      iex> detect_stdlib_module(Logger)
      {:elixir, :logger}

      iex> detect_stdlib_module(:lists)
      {:erlang, :stdlib}

      iex> detect_stdlib_module(MyApp.MyModule)
      :user_code

  """
  def detect_stdlib_module(module) when is_atom(module) do
    # Handle Erlang atoms (they don't have the Elixir. prefix)
    if is_erlang_module?(module) do
      detect_erlang_module(module)
    else
      case Application.get_application(module) do
        app when app in @stdlib_apps ->
          {:elixir, app}

        app when app in @erlang_apps ->
          {:erlang, app}

        nil ->
          # Try using :code.which as fallback
          fallback_detection(module)

        _other_app ->
          :user_code
      end
    end
  end

  # Check if module is an Erlang module (atom without Elixir. prefix)
  defp is_erlang_module?(module) do
    module_string = Atom.to_string(module)
    not String.starts_with?(module_string, "Elixir.")
  end

  # Detect Erlang modules specifically
  defp detect_erlang_module(module) do
    case :code.which(module) do
      :preloaded ->
        {:erlang, :kernel}

      path when is_list(path) ->
        path_string = List.to_string(path)

        cond do
          String.contains?(path_string, "/lib/stdlib-") ->
            {:erlang, :stdlib}

          String.contains?(path_string, "/lib/kernel-") ->
            {:erlang, :kernel}

          String.contains?(path_string, "/lib/erts-") ->
            {:erlang, :kernel}

          true ->
            # Check if it's a known Erlang app
            case Application.get_application(module) do
              app when app in @erlang_apps -> {:erlang, app}
              _ -> :user_code
            end
        end

      _ ->
        :user_code
    end
  end

  # Fallback detection for modules not loaded in Application
  defp fallback_detection(module) do
    case :code.which(module) do
      :preloaded ->
        # Preloaded modules like :erlang are part of kernel
        {:erlang, :kernel}

      path when is_list(path) ->
        path_string = List.to_string(path)

        cond do
          String.contains?(path_string, "/lib/elixir/") ->
            {:elixir, :elixir}

          String.contains?(path_string, "/lib/logger/") ->
            {:elixir, :logger}

          String.contains?(path_string, "/lib/mix/") ->
            {:elixir, :mix}

          String.contains?(path_string, "/lib/ex_unit/") ->
            {:elixir, :ex_unit}

          String.contains?(path_string, "/lib/eex/") ->
            {:elixir, :eex}

          String.contains?(path_string, "/lib/iex/") ->
            {:elixir, :iex}

          String.contains?(path_string, "/lib/stdlib-") ->
            {:erlang, :stdlib}

          String.contains?(path_string, "/lib/kernel-") ->
            {:erlang, :kernel}

          String.contains?(path_string, "/lib/erlang/") ->
            {:erlang, :stdlib}

          true ->
            :user_code
        end

      _ ->
        :user_code
    end
  end

  @doc """
  Returns true if the module is from stdlib (Elixir or Erlang).

  ## Examples

      iex> stdlib_module?(String)
      true

      iex> stdlib_module?(MyApp.Module)
      false

  """
  def stdlib_module?(module) when is_atom(module) do
    case detect_stdlib_module(module) do
      :user_code -> false
      _ -> true
    end
  end
end
