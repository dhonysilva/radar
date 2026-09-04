defmodule Radar.TechRadar.FrontMatterWriter do
  @moduledoc """
  Renders validated item attributes and a markdown body back into
  `Radar.TechRadar.FrontMatterParser`'s front-matter file format — the
  inverse of parsing. Used only by the item-edit save path
  (`RadarWeb.RadarLive.Edit`).

  This module does not validate anything — by the time `render/2` is
  called, the caller has already validated field shapes and values (same
  division of responsibility as `FrontMatterParser` vs.
  `Radar.TechRadar.Release.build/3`).
  """

  @field_order [
    :title,
    :ring,
    :quadrant,
    :tags,
    :featured,
    :related,
    :type,
    :status,
    :stale_after,
    :sources
  ]

  @doc "Renders `attrs` (a map with the keys in `@field_order`) and `body` into a full markdown file's contents."
  @spec render(map(), String.t()) :: String.t()
  def render(attrs, body) do
    front_matter =
      @field_order
      |> Enum.map(&{&1, Map.get(attrs, &1)})
      |> Enum.reject(fn {_key, value} -> value in [nil, [], ""] end)
      |> Enum.map_join("\n", &render_line/1)

    "---\n#{front_matter}\n---\n\n#{String.trim(body)}\n"
  end

  defp render_line({:title, value}), do: "title: #{render_string(value)}"
  defp render_line({:type, value}), do: "type: #{render_string(value)}"
  defp render_line({:stale_after, value}), do: "stale_after: #{render_string(to_string(value))}"
  defp render_line({:ring, value}), do: "ring: #{value}"
  defp render_line({:quadrant, value}), do: "quadrant: #{value}"
  defp render_line({:status, value}), do: "status: #{value}"
  defp render_line({:featured, value}), do: "featured: #{value}"
  defp render_line({:tags, values}), do: "tags: #{render_list(values)}"
  defp render_line({:related, values}), do: "related: #{render_list(values)}"
  defp render_line({:sources, values}), do: "sources: #{render_list(values)}"

  defp render_string(value), do: "\"#{value}\""
  defp render_list(values), do: "[#{Enum.join(values, ", ")}]"
end
