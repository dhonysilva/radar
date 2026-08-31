defmodule Radar.TechRadar.ChartLayout do
  @moduledoc """
  Deterministic, non-overlapping blip placement for the radar SVG chart.

  Positions are derived purely from each item's id (via `:erlang.phash2/2`),
  never from `:rand` or list order, so the same set of items always
  produces the same layout. This module has no Phoenix dependency and is
  pure (no process state), so it is unit-testable standalone.
  """

  alias Radar.TechRadar.Config

  @margin_frac 0.10
  @pad_px 14
  @min_dist 14
  @max_iterations 200

  @type point :: %{x: float(), y: float()}
  @type geometry :: %{
          center: {number(), number()},
          chart_radius: number(),
          quadrant_order: [atom()]
        }

  @doc """
  Returns `%{item_id => %{x:, y:}}` for every item, positioned within its
  quadrant+ring annular sector without overlapping other items sharing that
  same sector. Items in different quadrant/ring cells never affect each
  other's placement.
  """
  @spec layout([Radar.TechRadar.Item.t()], geometry()) :: %{optional(String.t()) => point()}
  def layout(items, geometry) do
    items
    |> Enum.group_by(&{&1.quadrant, &1.ring})
    |> Enum.flat_map(fn {{quadrant, ring}, bucket_items} ->
      place_bucket(quadrant, ring, bucket_items, geometry)
    end)
    |> Map.new()
  end

  defp place_bucket(quadrant, ring, bucket_items, geometry) do
    bounds = bounds_for(quadrant, ring, geometry)

    bucket_items
    |> Enum.sort_by(& &1.id)
    |> Enum.map(&{&1.id, initial_point(&1.id, bounds)})
    |> relax(bounds)
  end

  defp bounds_for(quadrant, ring, %{
         center: center,
         chart_radius: chart_radius,
         quadrant_order: order
       }) do
    rings = Config.rings()
    ring_index = Enum.find_index(rings, &(&1.id == ring)) || 0
    inner_frac = if ring_index == 0, do: 0.0, else: Enum.at(rings, ring_index - 1).radius
    outer_frac = Enum.at(rings, ring_index).radius

    quadrant_index = Enum.find_index(order, &(&1 == quadrant)) || 0
    start_angle = quadrant_index * 90.0

    %{
      center: center,
      inner_r: inner_frac * chart_radius,
      outer_r: outer_frac * chart_radius,
      start_angle: start_angle,
      span: 90.0
    }
  end

  defp initial_point(id, bounds) do
    [a, b] = seeded_unit_floats(id, 2)

    angle = bounds.start_angle + bounds.span * (@margin_frac + a * (1 - 2 * @margin_frac))
    max_radius_span = max(bounds.outer_r - bounds.inner_r - 2 * @pad_px, 0)
    radius = bounds.inner_r + @pad_px + b * max_radius_span

    to_cartesian(bounds.center, angle, radius)
  end

  defp seeded_unit_floats(id, n) do
    for i <- 1..n, do: :erlang.phash2({id, i}, 1_000_000) / 1_000_000
  end

  defp to_cartesian({cx, cy}, angle_deg, radius) do
    radians = angle_deg * :math.pi() / 180
    %{x: cx + radius * :math.cos(radians), y: cy + radius * :math.sin(radians)}
  end

  defp relax(id_points, bounds) do
    ids = Enum.map(id_points, &elem(&1, 0))
    point_map = Map.new(id_points)

    final_map =
      Enum.reduce_while(1..@max_iterations, point_map, fn _iteration, acc ->
        {next_acc, moved?} = relax_pass(acc, ids, bounds)
        if moved?, do: {:cont, next_acc}, else: {:halt, next_acc}
      end)

    Enum.map(ids, fn id -> {id, Map.fetch!(final_map, id)} end)
  end

  defp relax_pass(point_map, ids, bounds) do
    pairs = for [id_a, id_b] <- combinations(ids), do: {id_a, id_b}

    Enum.reduce(pairs, {point_map, false}, fn {id_a, id_b}, {acc, moved?} ->
      point_a = Map.fetch!(acc, id_a)
      point_b = Map.fetch!(acc, id_b)
      dist = distance(point_a, point_b)

      if dist < @min_dist do
        {new_a, new_b} = push_apart(id_a, point_a, id_b, point_b, dist)

        acc =
          acc
          |> Map.put(id_a, clamp(new_a, bounds))
          |> Map.put(id_b, clamp(new_b, bounds))

        {acc, true}
      else
        {acc, moved?}
      end
    end)
  end

  defp combinations([]), do: []
  defp combinations([_]), do: []

  defp combinations([head | tail]) do
    Enum.map(tail, &[head, &1]) ++ combinations(tail)
  end

  defp distance(point_a, point_b) do
    :math.sqrt(:math.pow(point_a.x - point_b.x, 2) + :math.pow(point_a.y - point_b.y, 2))
  end

  defp push_apart(id_a, point_a, id_b, point_b, dist) do
    push = (@min_dist - dist) / 2

    {dx, dy} =
      if dist == 0 do
        fallback_vector(id_a, id_b)
      else
        {(point_a.x - point_b.x) / dist, (point_a.y - point_b.y) / dist}
      end

    {%{x: point_a.x + dx * push, y: point_a.y + dy * push},
     %{x: point_b.x - dx * push, y: point_b.y - dy * push}}
  end

  defp fallback_vector(id_a, id_b) do
    angle = :erlang.phash2({id_a, id_b}, 360) * :math.pi() / 180
    {:math.cos(angle), :math.sin(angle)}
  end

  # Clamps a perturbed point back into its ring/quadrant sector. Assumes the
  # sector doesn't wrap across the 0/360 seam (true for the four 90 degree
  # quadrant sectors under the small per-iteration pushes this module makes);
  # acceptable given the small number of items expected per quadrant+ring
  # cell.
  defp clamp(point, bounds) do
    {cx, cy} = bounds.center
    dx = point.x - cx
    dy = point.y - cy
    radius = :math.sqrt(dx * dx + dy * dy)
    angle = normalize_angle(:math.atan2(dy, dx) * 180 / :math.pi())

    margin = @margin_frac * bounds.span
    min_angle = bounds.start_angle + margin
    max_angle = bounds.start_angle + bounds.span - margin
    min_radius = bounds.inner_r + @pad_px
    max_radius = max(bounds.outer_r - @pad_px, min_radius)

    clamped_angle = angle |> max(min_angle) |> min(max_angle)
    clamped_radius = radius |> max(min_radius) |> min(max_radius)

    to_cartesian(bounds.center, clamped_angle, clamped_radius)
  end

  defp normalize_angle(angle) when angle < 0, do: angle + 360
  defp normalize_angle(angle), do: angle
end
