defmodule Engine.StdlibDetectorTest do
  use ExUnit.Case, async: true

  alias Engine.StdlibDetector

  describe "detect_stdlib_module/1 for Elixir core modules" do
    test "detects Enum as elixir stdlib" do
      assert {:elixir, :elixir} = StdlibDetector.detect_stdlib_module(Enum)
    end

    test "detects String as elixir stdlib" do
      assert {:elixir, :elixir} = StdlibDetector.detect_stdlib_module(String)
    end

    test "detects Map as elixir stdlib" do
      assert {:elixir, :elixir} = StdlibDetector.detect_stdlib_module(Map)
    end

    test "detects List as elixir stdlib" do
      assert {:elixir, :elixir} = StdlibDetector.detect_stdlib_module(List)
    end

    test "detects Kernel as elixir stdlib" do
      assert {:elixir, :elixir} = StdlibDetector.detect_stdlib_module(Kernel)
    end

    test "detects GenServer as elixir stdlib" do
      assert {:elixir, :elixir} = StdlibDetector.detect_stdlib_module(GenServer)
    end

    test "detects Supervisor as elixir stdlib" do
      assert {:elixir, :elixir} = StdlibDetector.detect_stdlib_module(Supervisor)
    end

    test "detects Application as elixir stdlib" do
      assert {:elixir, :elixir} = StdlibDetector.detect_stdlib_module(Application)
    end

    test "detects IO as elixir stdlib" do
      assert {:elixir, :elixir} = StdlibDetector.detect_stdlib_module(IO)
    end

    test "detects File as elixir stdlib" do
      assert {:elixir, :elixir} = StdlibDetector.detect_stdlib_module(File)
    end

    test "detects Path as elixir stdlib" do
      assert {:elixir, :elixir} = StdlibDetector.detect_stdlib_module(Path)
    end
  end

  describe "detect_stdlib_module/1 for Elixir protocols" do
    test "detects Enumerable protocol" do
      assert {:elixir, :elixir} = StdlibDetector.detect_stdlib_module(Enumerable)
    end

    test "detects String.Chars protocol" do
      assert {:elixir, :elixir} = StdlibDetector.detect_stdlib_module(String.Chars)
    end

    test "detects Inspect protocol" do
      assert {:elixir, :elixir} = StdlibDetector.detect_stdlib_module(Inspect)
    end

    test "detects Collectable protocol" do
      assert {:elixir, :elixir} = StdlibDetector.detect_stdlib_module(Collectable)
    end
  end

  describe "detect_stdlib_module/1 for Elixir applications" do
    test "detects Logger as logger app" do
      assert {:elixir, :logger} = StdlibDetector.detect_stdlib_module(Logger)
    end

    test "detects Mix.Task as mix app" do
      assert {:elixir, :mix} = StdlibDetector.detect_stdlib_module(Mix.Task)
    end

    test "detects ExUnit.Case as ex_unit app" do
      assert {:elixir, :ex_unit} = StdlibDetector.detect_stdlib_module(ExUnit.Case)
    end
  end

  describe "detect_stdlib_module/1 for Erlang modules" do
    test "detects :lists as erlang stdlib" do
      assert {:erlang, :stdlib} = StdlibDetector.detect_stdlib_module(:lists)
    end

    test "detects :maps as erlang stdlib" do
      assert {:erlang, :stdlib} = StdlibDetector.detect_stdlib_module(:maps)
    end

    test "detects :gen_server as erlang stdlib" do
      assert {:erlang, :stdlib} = StdlibDetector.detect_stdlib_module(:gen_server)
    end

    test "detects :ets as erlang stdlib" do
      assert {:erlang, :stdlib} = StdlibDetector.detect_stdlib_module(:ets)
    end

    test "detects :timer as erlang stdlib" do
      assert {:erlang, :stdlib} = StdlibDetector.detect_stdlib_module(:timer)
    end

    test "detects :erlang as kernel" do
      assert {:erlang, :kernel} = StdlibDetector.detect_stdlib_module(:erlang)
    end

    test "detects :code as kernel" do
      assert {:erlang, :kernel} = StdlibDetector.detect_stdlib_module(:code)
    end
  end

  describe "detect_stdlib_module/1 for user code" do
    test "returns :user_code for undefined module" do
      # This module definitely doesn't exist
      assert :user_code = StdlibDetector.detect_stdlib_module(NonExistent.Module.Name)
    end
  end

  describe "stdlib_module?/1" do
    test "returns true for Elixir stdlib" do
      assert StdlibDetector.stdlib_module?(String)
      assert StdlibDetector.stdlib_module?(Enum)
    end

    test "returns true for Erlang stdlib" do
      assert StdlibDetector.stdlib_module?(:lists)
      assert StdlibDetector.stdlib_module?(:maps)
    end

    test "returns false for user code" do
      refute StdlibDetector.stdlib_module?(NonExistent.Module)
    end
  end
end
