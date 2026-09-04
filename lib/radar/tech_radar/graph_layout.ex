defmodule Radar.TechRadar.GraphLayout do
  @moduledoc """
  Deterministic force-directed layout for the items graph (nodes = items,
  edges = `related` links), used by the graph view
  (`RadarWeb.RadarLive.Graph`).

  Positions are derived purely from item ids (via `:erlang.phash2/2` for
  initial placement) and a fixed number of relaxation passes — never from
  `:rand` — so the same set of items and edges always produces the same
  layout. Computed once, at compile time, by `Radar.TechRadar`; never
  recomputed at runtime. This module has no Phoenix dependency and is pure
  (no process state), so it is unit-testable standalone.

  Uses the Fruchterman-Reingold force-directed algorithm: every pair of
  nodes repels each other, every edge pulls its two endpoints together, and
  a mild centering force keeps the whole layout from drifting off-canvas. A
  linearly cooling "temperature" caps how far a node can move per pass,
  which is what makes a fixed number of passes converge to a stable,
  non-oscillating layout instead of jittering forever.
  """

  alias Radar.TechRadar.Item

  @passes 300
  @margin_frac 0.08
  @gravity 0.02

  @type point :: %{x: float(), y: float()}
  @type edge :: {String.t(), String.t()}
  @type geometry :: %{width: number(), height: number()}

  @doc """
  Returns `%{positions: %{item_id => %{x:, y:}}, edges: [{id, id}]}` for
  `items`, deriving edges from their `related` fields.
  """
  @spec layout([Item.t()], geometry()) :: %{
          positions: %{optional(String.t()) => point()},
          edges: [edge()]
        }
  def layout(items, geometry) do
    edges = edges_from(items)

    positions =
      items
      |> Enum.map(& &1.id)
      |> initial_positions(geometry)
      |> relax(edges, geometry)

    %{positions: positions, edges: edges}
  end

  @doc """
  Undirected, deduplicated `related` edges — an id pair appears at most
  once regardless of which item(s) listed it, and regardless of link
  direction (`a` related to `b` and/or `b` related to `a` both collapse to
  the same edge). Ids not present in `items` are ignored defensively (all
  `related` ids are already validated at compile time by
  `Radar.TechRadar`, so this should never actually filter anything out —
  it's a safety net, not load-bearing).
  """
  @spec edges_from([Item.t()]) :: [edge()]
  def edges_from(items) do
    known_ids = MapSet.new(items, & &1.id)

    items
    |> Enum.flat_map(fn item ->
      for related_id <- item.related, MapSet.member?(known_ids, related_id) do
        if item.id < related_id, do: {item.id, related_id}, else: {related_id, item.id}
      end
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp initial_positions(ids, geometry) do
    Map.new(ids, fn id ->
      [a, b] = seeded_unit_floats(id, 2)
      {id, %{x: a * geometry.width, y: b * geometry.height}}
    end)
  end

  defp seeded_unit_floats(id, n) do
    for i <- 1..n, do: :erlang.phash2({id, i}, 1_000_000) / 1_000_000
  end

  defp relax(positions, edges, geometry) do
    node_count = map_size(positions)
    area = geometry.width * geometry.height
    k = :math.sqrt(area / max(node_count, 1))
    center = %{x: geometry.width / 2, y: geometry.height / 2}

    Enum.reduce(1..@passes, positions, fn pass, acc ->
      temperature = k * (1 - pass / @passes)
      relax_pass(acc, edges, k, center, temperature, geometry)
    end)
  end

  defp relax_pass(positions, edges, k, center, temperature, geometry) do
    ids = Map.keys(positions)

    displacements =
      ids
      |> Map.new(&{&1, %{x: 0.0, y: 0.0}})
      |> apply_repulsion(positions, ids, k)
      |> apply_attraction(positions, edges, k)
      |> apply_gravity(positions, center)

    Map.new(ids, fn id ->
      {id, move(Map.fetch!(positions, id), Map.fetch!(displacements, id), temperature, geometry)}
    end)
  end

  defp move(point, displacement, temperature, geometry) do
    dist = vector_length(displacement)

    capped =
      if dist > 0 do
        scale = min(dist, temperature) / dist
        %{x: displacement.x * scale, y: displacement.y * scale}
      else
        displacement
      end

    clamp(%{x: point.x + capped.x, y: point.y + capped.y}, geometry)
  end

  defp apply_repulsion(displacements, positions, ids, k) do
    for id_a <- ids, id_b <- ids, id_a < id_b, reduce: displacements do
      acc ->
        point_a = Map.fetch!(positions, id_a)
        point_b = Map.fetch!(positions, id_b)
        {dx, dy, dist} = delta(point_a, point_b)
        force = k * k / dist

        acc
        |> add(id_a, dx / dist * force, dy / dist * force)
        |> add(id_b, -(dx / dist * force), -(dy / dist * force))
    end
  end

  defp apply_attraction(displacements, positions, edges, k) do
    Enum.reduce(edges, displacements, fn {id_a, id_b}, acc ->
      point_a = Map.fetch!(positions, id_a)
      point_b = Map.fetch!(positions, id_b)
      {dx, dy, dist} = delta(point_a, point_b)
      force = dist * dist / k

      acc
      |> add(id_a, -(dx / dist * force), -(dy / dist * force))
      |> add(id_b, dx / dist * force, dy / dist * force)
    end)
  end

  defp apply_gravity(displacements, positions, center) do
    Enum.reduce(Map.keys(displacements), displacements, fn id, acc ->
      point = Map.fetch!(positions, id)
      add(acc, id, (center.x - point.x) * @gravity, (center.y - point.y) * @gravity)
    end)
  end

  defp add(displacements, id, dx, dy) do
    Map.update!(displacements, id, fn %{x: x, y: y} -> %{x: x + dx, y: y + dy} end)
  end

  defp delta(point_a, point_b) do
    dx = point_a.x - point_b.x
    dy = point_a.y - point_b.y
    dist = max(:math.sqrt(dx * dx + dy * dy), 0.01)
    {dx, dy, dist}
  end

  defp vector_length(%{x: x, y: y}), do: :math.sqrt(x * x + y * y)

  defp clamp(point, geometry) do
    margin_x = @margin_frac * geometry.width
    margin_y = @margin_frac * geometry.height

    %{
      x: point.x |> max(margin_x) |> min(geometry.width - margin_x),
      y: point.y |> max(margin_y) |> min(geometry.height - margin_y)
    }
  end
end
