defmodule Radar.TechRadar.ChartLayoutTest do
  use ExUnit.Case, async: true

  alias Radar.TechRadar.{ChartLayout, Config, Item}

  @geometry %{
    center: {300, 300},
    chart_radius: 260,
    quadrant_order: [:techniques, :tools, :platforms, :"languages-and-frameworks"]
  }

  @min_dist 14

  defp item(id, quadrant, ring) do
    struct!(Item,
      id: id,
      title: id,
      quadrant: quadrant,
      ring: ring,
      tags: [],
      featured: true,
      related: [],
      body_html: "",
      release_date: ~D[2024-01-01],
      history: [],
      flag: nil
    )
  end

  defp bucket(count, quadrant, ring) do
    for i <- 1..count, do: item("item-#{quadrant}-#{ring}-#{i}", quadrant, ring)
  end

  defp distance(a, b), do: :math.sqrt(:math.pow(a.x - b.x, 2) + :math.pow(a.y - b.y, 2))

  test "layout is deterministic for the same input" do
    items = bucket(12, :techniques, :adopt) ++ bucket(5, :tools, :trial)

    assert ChartLayout.layout(items, @geometry) == ChartLayout.layout(items, @geometry)
  end

  test "items in the same quadrant+ring cell never overlap" do
    for count <- [1, 2, 10, 30] do
      items = bucket(count, :platforms, :assess)
      positions = ChartLayout.layout(items, @geometry) |> Map.values()

      for [a, b] <- combinations(positions) do
        assert distance(a, b) >= @min_dist - 0.01
      end
    end
  end

  test "positioning one bucket never affects another quadrant+ring cell" do
    items_a = bucket(8, :techniques, :adopt)
    positions_a_alone = ChartLayout.layout(items_a, @geometry)

    items_b = bucket(3, :tools, :hold)
    positions_combined = ChartLayout.layout(items_a ++ items_b, @geometry)

    for item <- items_a do
      assert positions_a_alone[item.id] == positions_combined[item.id]
    end
  end

  test "every point stays within its ring's annulus around the chart center" do
    items = bucket(20, :"languages-and-frameworks", :adopt)

    positions = ChartLayout.layout(items, @geometry)
    {cx, cy} = @geometry.center

    adopt_radius_fraction = Config.ring(:adopt).radius
    outer_r = adopt_radius_fraction * @geometry.chart_radius
    pad = 14
    min_radius = pad
    max_radius = max(outer_r - pad, min_radius)

    for {_id, point} <- positions do
      radius = :math.sqrt(:math.pow(point.x - cx, 2) + :math.pow(point.y - cy, 2))
      assert radius >= min_radius - 0.01
      assert radius <= max_radius + 0.01
    end
  end

  defp combinations([]), do: []
  defp combinations([_]), do: []
  defp combinations([head | tail]), do: Enum.map(tail, &[head, &1]) ++ combinations(tail)
end
