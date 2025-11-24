defmodule Engine.CodeIntelligence.Definition do
  @moduledoc """
  Provides jump-to-definition functionality with best-effort arity matching.

  When an exact function arity match is not found (e.g., user refactored func/3 to func/4),
  this module falls back to the closest available arity using distance-based matching:

  - Distance = abs(available_arity - target_arity)
  - Selects minimum distance
  - Tie-breaker: prefers lowest arity

  ## Examples

      # Exact match: finds func/3
      definition(document, position_at_func_call_with_3_args)

      # Fallback: calling func/2 when only func/1 and func/3 exist
      # Both have distance 1, prefers func/1 (lowest)
      definition(document, position_at_func_call_with_2_args)
  """

  alias ElixirSense.Providers.Location, as: ElixirSenseLocation
  alias Engine.CodeIntelligence.Entity
  alias Engine.Search.Store
  alias Forge.Ast
  alias Forge.Ast.Analysis
  alias Forge.Document
  alias Forge.Document.Location
  alias Forge.Document.Position
  alias Forge.Formats
  alias Forge.Search.Indexer.Entry
  alias Forge.Text
  alias Future.Code

  require Logger

  @spec definition(Document.t(), Position.t()) :: {:ok, [Location.t()]} | {:error, String.t()}
  def definition(%Document{} = document, %Position{} = position) do
    with {:ok, _, analysis} <- Document.Store.fetch(document.uri, :analysis),
         {:ok, entity, _range} <- Entity.resolve(analysis, position) do
      fetch_definition(entity, analysis, position)
    end
  end

  defp fetch_definition({type, entity} = resolved, %Analysis{} = analysis, %Position{} = position)
       when type in [:struct, :module] do
    module = Formats.module(entity)

    locations =
      case Store.exact(module, type: type, subtype: :definition) do
        {:ok, entries} ->
          for entry <- entries,
              result = to_location(entry),
              match?({:ok, _}, result) do
            {:ok, location} = result
            location
          end

        _ ->
          []
      end

    maybe_fallback_to_elixir_sense(resolved, locations, analysis, position)
  end

  defp fetch_definition(
         {:call, module, function, arity} = resolved,
         %Analysis{} = analysis,
         %Position{} = position
       ) do
    mfa = Formats.mfa(module, function, arity)

    definitions =
      mfa
      |> query_with_fallback(subtype: :definition)
      |> Stream.flat_map(fn entry ->
        case entry do
          %Entry{type: {:function, :delegate}} ->
            mfa = get_in(entry, [:metadata, :original_mfa])
            query_search_index(mfa, subtype: :definition) ++ [entry]

          _ ->
            [entry]
        end
      end)
      |> Stream.uniq_by(& &1.subject)

    locations =
      for entry <- definitions,
          result = to_location(entry),
          match?({:ok, _}, result) do
        {:ok, location} = result
        location
      end

    maybe_fallback_to_elixir_sense(resolved, locations, analysis, position)
  end

  defp fetch_definition(_, %Analysis{} = analysis, %Position{} = position) do
    elixir_sense_definition(analysis, position)
  end

  defp maybe_fallback_to_elixir_sense(resolved, locations, analysis, position) do
    case locations do
      [] ->
        Logger.info("No definition found for #{inspect(resolved)} with Indexer.")

        elixir_sense_definition(analysis, position)

      [location] ->
        {:ok, location}

      _ ->
        {:ok, locations}
    end
  end

  defp elixir_sense_definition(%Analysis{} = analysis, %Position{} = position) do
    analysis.document
    |> Document.to_string()
    |> ElixirSense.definition(position.line, position.character)
    |> parse_location(analysis.document)
  end

  defp parse_location(%ElixirSenseLocation{} = location, document) do
    %{file: file, line: line, column: column, type: type} = location
    file_path = file || document.path
    uri = Document.Path.ensure_uri(file_path)

    with {:ok, document} <- Document.Store.open_temporary(uri),
         {:ok, text} <- Document.fetch_text_at(document, line) do
      {line, column} = maybe_move_cursor_to_next_token(type, document, line, column)
      range = to_precise_range(document, text, line, column)
      {:ok, Location.new(range, document)}
    else
      _ ->
        {:error, "Could not open source file or fetch line text: #{inspect(file_path)}"}
    end
  end

  defp parse_location(nil, _) do
    {:ok, nil}
  end

  defp maybe_move_cursor_to_next_token(type, document, line, column)
       when type in [:function, :module, :macro] do
    position = Position.new(document, line, column)

    with {:ok, zipper} <- Ast.zipper_at(document, position),
         %{node: {entity_name, meta, _}} <- Sourceror.Zipper.next(zipper) do
      meta =
        if entity_name == :when do
          %{node: {_entity_name, meta, _}} = Sourceror.Zipper.next(zipper)
          meta
        else
          meta
        end

      {meta[:line], meta[:column]}
    else
      _ ->
        {line, column}
    end
  end

  defp maybe_move_cursor_to_next_token(_, _, line, column), do: {line, column}

  defp to_precise_range(%Document{} = document, text, line, column) do
    case Code.Fragment.surround_context(text, {line, column}) do
      %{begin: start_pos, end: end_pos} ->
        Entity.to_range(document, start_pos, end_pos)

      _ ->
        # If the column is 1, but the code doesn't start on the first column, which isn't what we want.
        # The cursor will be placed to the left of the actual definition.
        column = if column == 1, do: Text.count_leading_spaces(text) + 1, else: column
        pos = {line, column}
        Entity.to_range(document, pos, pos)
    end
  end

  defp to_location(entry) do
    uri = Document.Path.ensure_uri(entry.path)

    case Document.Store.open_temporary(uri) do
      {:ok, document} ->
        {:ok, Location.new(entry.range, document)}

      _ ->
        :error
    end
  end

  defp query_search_index(subject, condition) do
    case Store.exact(subject, condition) do
      {:ok, entries} ->
        entries

      _ ->
        []
    end
  end

  # Queries the search index with best-effort arity matching.
  # First tries an exact match. If no results are found, attempts to find
  # the closest available arity using distance-based matching.
  defp query_with_fallback(subject, condition) do
    case query_search_index(subject, condition) do
      [] ->
        # No exact match found, try arity fallback
        query_closest_arity(subject, condition)

      entries ->
        entries
    end
  end

  # Queries for the closest available arity when exact match fails.
  # Uses prefix matching to find all available arities for the given
  # module and function, then selects the closest one based on distance.
  defp query_closest_arity(subject, condition) do
    with {:ok, target_arity} <- extract_arity_from_subject(subject),
         prefix <- build_function_prefix(subject),
         {:ok, entries} <- Store.prefix(prefix, condition),
         filtered_entries <- Enum.filter(entries, &match_function_pattern?(&1.subject, prefix)) do
      select_closest_arity_entries(filtered_entries, target_arity)
    else
      _ -> []
    end
  end

  # Extracts the arity from a subject string like "Module.func/3".
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

  # Builds a prefix for function matching from a subject like "Module.func/3".
  # Returns "Module.func/" which can be used for prefix queries.
  defp build_function_prefix(subject) when is_binary(subject) do
    case String.split(subject, "/") do
      [prefix, _arity] -> prefix <> "/"
      _ -> subject
    end
  end

  # Checks if a subject matches the function prefix pattern.
  # This ensures we only match functions with the same module and name,
  # not partial matches.
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

  # Selects entries with the closest arity to the target.
  # Algorithm:
  # - Calculate distance = abs(available_arity - target_arity)
  # - Select entries with minimum distance
  # - Tie-breaker: prefer lowest arity
  defp select_closest_arity_entries([], _target_arity), do: []

  defp select_closest_arity_entries(entries, target_arity) do
    # Group entries by arity and calculate distances
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
        # Find minimum distance
        min_distance =
          entries_with_distance
          |> Enum.map(fn {_entry, _arity, distance} -> distance end)
          |> Enum.min()

        # Filter entries with minimum distance
        closest_entries =
          entries_with_distance
          |> Enum.filter(fn {_entry, _arity, distance} -> distance == min_distance end)

        # If tie, prefer lowest arity
        {entry, _arity, _distance} =
          Enum.min_by(closest_entries, fn {_entry, arity, _distance} -> arity end)

        # Return all entries with the same subject (same arity but different clauses)
        selected_subject = entry.subject

        Enum.filter(entries, fn e -> e.subject == selected_subject end)
    end
  end
end
