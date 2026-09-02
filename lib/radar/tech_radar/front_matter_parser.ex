defmodule Radar.TechRadar.FrontMatterParser do
  @moduledoc """
  A `NimblePublisher` parser for the AOE Technology Radar's markdown
  front-matter format:

      ---
      title: "React"
      ring: adopt
      quadrant: languages-and-frameworks
      tags: [frontend, coding]
      featured: true
      related: [typescript, nextjs]
      type: "Radar Item"
      status: stable
      stale_after: "2026-12-31"
      sources: [https://example.com/postmortem]
      ---
      Body markdown...

  This intentionally supports only the handful of value shapes radar items
  need (quoted/bare strings, bracketed lists, booleans) via a small
  hand-rolled parser — it is not a general-purpose YAML parser, and does not
  pull in a YAML dependency for four simple field types.

  Values are returned as plain strings/lists/booleans; this module does not
  coerce anything to atoms (see `Radar.TechRadar.Release.build/3` for the
  allowlisted `ring`/`quadrant` atom lookup).
  """

  @front_matter_regex ~r/\A---\r?\n(?<front>.*?)\r?\n---\r?\n?(?<body>.*)\z/s

  @known_keys %{
    "title" => :title,
    "ring" => :ring,
    "quadrant" => :quadrant,
    "tags" => :tags,
    "featured" => :featured,
    "related" => :related,
    "type" => :type,
    "status" => :status,
    "stale_after" => :stale_after,
    "sources" => :sources
  }

  @doc """
  The `NimblePublisher` parser callback: receives a file's path and raw
  contents, returns `{attrs, body}` where `attrs` has atom keys for the
  known front-matter fields and `body` is the raw (unrendered) markdown.
  """
  def parse(path, contents) do
    case Regex.named_captures(@front_matter_regex, contents) do
      %{"front" => front, "body" => body} ->
        {parse_front_matter(front, path), body}

      nil ->
        raise "#{path}: missing or malformed front matter (expected a leading and closing `---` block)"
    end
  end

  defp parse_front_matter(front, path) do
    front
    |> String.split(["\n", "\r\n"])
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Map.new(&parse_line(&1, path))
  end

  defp parse_line(line, path) do
    case String.split(line, ":", parts: 2) do
      [key, value] ->
        {front_matter_key(String.trim(key), line, path), parse_value(String.trim(value))}

      _ ->
        raise "#{path}: could not parse front matter line #{inspect(line)}"
    end
  end

  defp front_matter_key(key, line, path) do
    case Map.fetch(@known_keys, key) do
      {:ok, atom_key} ->
        atom_key

      :error ->
        raise "#{path}: unknown front matter key #{inspect(key)} in line #{inspect(line)}"
    end
  end

  defp parse_value("true"), do: true
  defp parse_value("false"), do: false

  defp parse_value("[" <> rest) do
    rest
    |> String.trim_trailing("]")
    |> String.split(",")
    |> Enum.map(&unquote_string/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp parse_value(value), do: unquote_string(value)

  defp unquote_string(value) do
    value
    |> String.trim()
    |> String.trim("\"")
    |> String.trim("'")
  end
end
