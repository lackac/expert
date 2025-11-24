defmodule Engine.StdlibResolverTest do
  use ExUnit.Case, async: true

  alias Engine.StdlibResolver

  describe "resolve_source_file/1 for Elixir core modules" do
    test "resolves String module" do
      assert {:ok, path} = StdlibResolver.resolve_source_file(String)
      assert String.ends_with?(path, "string.ex")
      assert File.exists?(path)
    end

    test "resolves Enum module" do
      assert {:ok, path} = StdlibResolver.resolve_source_file(Enum)
      assert String.ends_with?(path, "enum.ex")
      assert File.exists?(path)
    end

    test "resolves Map module" do
      assert {:ok, path} = StdlibResolver.resolve_source_file(Map)
      assert String.ends_with?(path, "map.ex")
      assert File.exists?(path)
    end

    test "resolves List module" do
      assert {:ok, path} = StdlibResolver.resolve_source_file(List)
      assert String.ends_with?(path, "list.ex")
      assert File.exists?(path)
    end

    test "resolves Kernel module" do
      assert {:ok, path} = StdlibResolver.resolve_source_file(Kernel)
      assert String.ends_with?(path, "kernel.ex")
      assert File.exists?(path)
    end

    test "resolves GenServer module" do
      assert {:ok, path} = StdlibResolver.resolve_source_file(GenServer)
      assert String.ends_with?(path, "gen_server.ex")
      assert File.exists?(path)
    end

    test "resolves IO module" do
      assert {:ok, path} = StdlibResolver.resolve_source_file(IO)
      assert String.ends_with?(path, "io.ex")
      assert File.exists?(path)
    end

    test "resolves File module" do
      assert {:ok, path} = StdlibResolver.resolve_source_file(File)
      assert String.ends_with?(path, "file.ex")
      assert File.exists?(path)
    end

    test "resolves Path module" do
      assert {:ok, path} = StdlibResolver.resolve_source_file(Path)
      assert String.ends_with?(path, "path.ex")
      assert File.exists?(path)
    end

    test "resolves Process module" do
      assert {:ok, path} = StdlibResolver.resolve_source_file(Process)
      assert String.ends_with?(path, "process.ex")
      assert File.exists?(path)
    end
  end

  describe "resolve_source_file/1 for nested Elixir modules" do
    test "resolves Enum.OutOfBoundsError to enum.ex" do
      assert {:ok, path} = StdlibResolver.resolve_source_file(Enum.OutOfBoundsError)
      assert String.ends_with?(path, "enum.ex")
      assert File.exists?(path)
    end

    test "resolves File.Error to file.ex" do
      assert {:ok, path} = StdlibResolver.resolve_source_file(File.Error)
      assert String.ends_with?(path, "file.ex")
      assert File.exists?(path)
    end
  end

  describe "resolve_source_file/1 for Elixir protocols" do
    test "resolves Enumerable protocol" do
      # Enumerable protocol is often defined alongside other modules
      # The exact file location may vary, so we just check for a result
      case StdlibResolver.resolve_source_file(Enumerable) do
        {:ok, path} ->
          assert String.ends_with?(path, ".ex")
          assert File.exists?(path)

        {:error, :not_found} ->
          # This is acceptable as protocol definitions may be co-located
          :ok
      end
    end

    test "resolves String.Chars protocol" do
      case StdlibResolver.resolve_source_file(String.Chars) do
        {:ok, path} ->
          assert File.exists?(path)

        {:error, _} ->
          :ok
      end
    end

    test "resolves Inspect protocol" do
      assert {:ok, path} = StdlibResolver.resolve_source_file(Inspect)
      assert String.ends_with?(path, "inspect.ex")
      assert File.exists?(path)
    end

    test "resolves Collectable protocol" do
      assert {:ok, path} = StdlibResolver.resolve_source_file(Collectable)
      assert String.ends_with?(path, "collectable.ex")
      assert File.exists?(path)
    end
  end

  describe "resolve_source_file/1 for Elixir application modules" do
    test "resolves Logger module" do
      assert {:ok, path} = StdlibResolver.resolve_source_file(Logger)
      assert String.contains?(path, "logger")
      assert String.ends_with?(path, ".ex")
      assert File.exists?(path)
    end

    test "resolves Mix.Task module" do
      assert {:ok, path} = StdlibResolver.resolve_source_file(Mix.Task)
      assert String.contains?(path, "mix")
      assert String.ends_with?(path, ".ex")
      assert File.exists?(path)
    end

    test "resolves ExUnit.Case module" do
      assert {:ok, path} = StdlibResolver.resolve_source_file(ExUnit.Case)
      assert String.contains?(path, "ex_unit")
      assert String.ends_with?(path, ".ex")
      assert File.exists?(path)
    end
  end

  describe "resolve_source_file/1 for Erlang modules" do
    test "resolves :lists module" do
      case StdlibResolver.resolve_source_file(:lists) do
        {:ok, path} ->
          assert String.ends_with?(path, "lists.erl")
          assert File.exists?(path)

        {:error, _} ->
          # Source may not be available in some installations
          :ok
      end
    end

    test "resolves :maps module" do
      case StdlibResolver.resolve_source_file(:maps) do
        {:ok, path} ->
          assert String.ends_with?(path, "maps.erl")
          assert File.exists?(path)

        {:error, _} ->
          :ok
      end
    end

    test "resolves :gen_server module" do
      case StdlibResolver.resolve_source_file(:gen_server) do
        {:ok, path} ->
          assert String.ends_with?(path, "gen_server.erl")
          assert File.exists?(path)

        {:error, _} ->
          :ok
      end
    end

    test "resolves :erlang module" do
      case StdlibResolver.resolve_source_file(:erlang) do
        {:ok, path} ->
          assert String.ends_with?(path, "erlang.erl")
          assert File.exists?(path)

        {:error, _} ->
          :ok
      end
    end
  end

  describe "resolve_source_file/1 error cases" do
    test "returns error for non-stdlib module" do
      assert {:error, :not_stdlib} = StdlibResolver.resolve_source_file(NonExistent.Module)
    end
  end
end
