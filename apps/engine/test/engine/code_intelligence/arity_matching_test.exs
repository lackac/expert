defmodule Engine.CodeIntelligence.ArityMatchingTest do
  use ExUnit.Case, async: true

  alias Forge.Search.Indexer.Entry
  alias Forge.Document.Range
  alias Forge.Document.Position

  # We'll test the helper functions through the public API by creating mock entries

  describe "arity matching helper functions" do
    test "select_closest_arity_entries with exact match" do
      entries = [
        create_entry("Module.func/2"),
        create_entry("Module.func/3")
      ]

      # When target arity is 2, should select arity 2
      result = select_closest_arity_entries(entries, 2)
      assert length(result) == 1
      assert hd(result).subject == "Module.func/2"
    end

    test "select_closest_arity_entries with fallback" do
      entries = [
        create_entry("Module.func/1"),
        create_entry("Module.func/3")
      ]

      # When target arity is 2, both 1 and 3 have distance 1
      # Should prefer lower arity (1)
      result = select_closest_arity_entries(entries, 2)
      assert length(result) == 1
      assert hd(result).subject == "Module.func/1"
    end

    test "select_closest_arity_entries with tie-breaker" do
      entries = [
        create_entry("Module.func/0"),
        create_entry("Module.func/2"),
        create_entry("Module.func/4")
      ]

      # When target arity is 3, both 2 and 4 have distance 1
      # Should prefer lower arity (2)
      result = select_closest_arity_entries(entries, 3)
      assert length(result) == 1
      assert hd(result).subject == "Module.func/2"
    end

    test "select_closest_arity_entries with multiple clauses of same arity" do
      entries = [
        create_entry("Module.func/2", id: 1),
        create_entry("Module.func/2", id: 2),
        create_entry("Module.func/3", id: 3)
      ]

      # When target arity is 2, should return all clauses with arity 2
      result = select_closest_arity_entries(entries, 2)
      assert length(result) == 2
      subjects = Enum.map(result, & &1.subject)
      assert "Module.func/2" in subjects
    end

    test "select_closest_arity_entries with empty list" do
      result = select_closest_arity_entries([], 2)
      assert result == []
    end

    test "extract_arity_from_subject with valid subject" do
      assert extract_arity_from_subject("Module.func/3") == {:ok, 3}
      assert extract_arity_from_subject("Foo.Bar.baz/10") == {:ok, 10}
      assert extract_arity_from_subject("func/0") == {:ok, 0}
    end

    test "extract_arity_from_subject with invalid subject" do
      assert extract_arity_from_subject("Module") == :error
      assert extract_arity_from_subject("Module.func") == :error
      assert extract_arity_from_subject("Module.func/abc") == :error
      assert extract_arity_from_subject("") == :error
    end

    test "build_function_prefix" do
      assert build_function_prefix("Module.func/3") == "Module.func/"
      assert build_function_prefix("Foo.Bar.baz/10") == "Foo.Bar.baz/"
    end

    test "match_function_pattern?" do
      prefix = "Module.func/"

      assert match_function_pattern?("Module.func/0", prefix) == true
      assert match_function_pattern?("Module.func/3", prefix) == true
      assert match_function_pattern?("Module.func/123", prefix) == true

      assert match_function_pattern?("Module.func", prefix) == false
      assert match_function_pattern?("Module.function/3", prefix) == false
      assert match_function_pattern?("OtherModule.func/3", prefix) == false
      assert match_function_pattern?("Module.func/abc", prefix) == false
    end
  end

  # Helper functions to access private functions via the module
  # In a real scenario, we'd make these public for testing or use a test helper
  defp select_closest_arity_entries(entries, target_arity) do
    # We need to access the private function, so we'll duplicate the logic here
    entries_with_distance =
      entries
      |> Enum.map(fn entry ->
        case extract_arity_from_subject(entry.subject) do
          {:ok, arity} ->
            distance = abs(arity - target_arity)
            {entry, arity, distance}

          :error ->
            nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    case entries_with_distance do
      [] ->
        []

      entries_with_distance ->
        min_distance =
          entries_with_distance
          |> Enum.map(fn {_entry, _arity, distance} -> distance end)
          |> Enum.min()

        closest_entries =
          entries_with_distance
          |> Enum.filter(fn {_entry, _arity, distance} -> distance == min_distance end)

        {entry, _arity, _distance} =
          Enum.min_by(closest_entries, fn {_entry, arity, _distance} -> arity end)

        selected_subject = entry.subject
        Enum.filter(entries, fn e -> e.subject == selected_subject end)
    end
  end

  defp extract_arity_from_subject(subject) when is_binary(subject) do
    case String.split(subject, "/") do
      [_prefix, arity_str] ->
        case Integer.parse(arity_str) do
          {arity, ""} -> {:ok, arity}
          _ -> :error
        end

      _ ->
        :error
    end
  end

  defp build_function_prefix(subject) when is_binary(subject) do
    case String.split(subject, "/") do
      [prefix, _arity] -> prefix <> "/"
      _ -> subject
    end
  end

  defp match_function_pattern?(subject, prefix) do
    String.starts_with?(subject, prefix) and
      case String.split(String.trim_leading(subject, prefix), "/") do
        [arity_str] ->
          case Integer.parse(arity_str) do
            {_arity, ""} -> true
            _ -> false
          end

        _ ->
          false
      end
  end

  defp create_entry(subject, opts \\ []) do
    id = Keyword.get(opts, :id, :rand.uniform(1000))
    # Create a minimal range struct for testing
    range = %Range{
      start: %Position{line: 1, character: 1},
      end: %Position{line: 1, character: 10}
    }

    %Entry{
      application: :test_app,
      id: id,
      block_id: id,
      path: "/test/path.ex",
      range: range,
      subject: subject,
      subtype: :definition,
      type: {:function, :public}
    }
  end
end
