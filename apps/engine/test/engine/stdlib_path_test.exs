defmodule Engine.StdlibPathTest do
  use ExUnit.Case, async: true

  alias Engine.StdlibPath

  describe "elixir_source_dir/0" do
    test "returns a valid directory path" do
      dir = StdlibPath.elixir_source_dir()
      assert is_binary(dir)
      assert String.contains?(dir, "elixir")
    end

    test "returned directory exists" do
      dir = StdlibPath.elixir_source_dir()
      assert File.dir?(dir), "Expected #{dir} to be a directory"
    end

    test "directory contains source files" do
      dir = StdlibPath.elixir_source_dir()
      assert StdlibPath.source_dir_available?(dir)
    end

    test "directory contains expected stdlib files" do
      dir = StdlibPath.elixir_source_dir()
      {:ok, files} = File.ls(dir)

      # Core modules should be present
      assert "enum.ex" in files
      assert "string.ex" in files
      assert "map.ex" in files
    end
  end

  describe "erlang_source_dir/1" do
    test "returns a valid directory for :stdlib" do
      dir = StdlibPath.erlang_source_dir(:stdlib)
      assert is_binary(dir) or is_nil(dir)

      if dir do
        assert String.contains?(dir, "stdlib")
      end
    end

    test "returns a valid directory for :kernel" do
      dir = StdlibPath.erlang_source_dir(:kernel)
      assert is_binary(dir) or is_nil(dir)

      if dir do
        assert String.contains?(dir, "kernel")
      end
    end

    test "directory contains erlang source files when available" do
      dir = StdlibPath.erlang_source_dir(:stdlib)

      if dir && File.dir?(dir) do
        {:ok, files} = File.ls(dir)
        # Should contain .erl files
        assert Enum.any?(files, &String.ends_with?(&1, ".erl"))
      end
    end
  end

  describe "elixir_app_source_dir/1" do
    test "returns a valid directory for :logger" do
      dir = StdlibPath.elixir_app_source_dir(:logger)
      assert is_binary(dir) or is_nil(dir)

      if dir do
        assert String.contains?(dir, "logger")
      end
    end

    test "returns a valid directory for :mix" do
      dir = StdlibPath.elixir_app_source_dir(:mix)
      assert is_binary(dir) or is_nil(dir)

      if dir do
        assert String.contains?(dir, "mix")
      end
    end

    test "returns a valid directory for :ex_unit" do
      dir = StdlibPath.elixir_app_source_dir(:ex_unit)
      assert is_binary(dir) or is_nil(dir)

      if dir do
        assert String.contains?(dir, "ex_unit")
      end
    end
  end

  describe "source_dir_available?/1" do
    test "returns false for nil" do
      refute StdlibPath.source_dir_available?(nil)
    end

    test "returns false for non-existent directory" do
      refute StdlibPath.source_dir_available?("/nonexistent/path")
    end

    test "returns true for valid elixir source directory" do
      dir = StdlibPath.elixir_source_dir()
      assert StdlibPath.source_dir_available?(dir)
    end
  end
end
