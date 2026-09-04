defmodule Radar.TechRadar.GraphLayoutTest do
  use ExUnit.Case, async: true

  alias Radar.TechRadar.{GraphLayout, Item}

  @geometry %{width: 900, height: 700}

  defp item(id, related \\ []) do
    struct!(Item,
      id: id,
      title: id,
      quadrant: :techniques,
      ring: :adopt,
      tags: [],
      featured: true,
      related: related,
      type: "Radar Item",
      status: :stable,
      stale_after: nil,
      sources: [],
      body_html: "",
      release_date: ~D[2024-01-01],
      history: [],
      flag: nil,
      path: "priv/radar/releases/2024-01-01/#{id}.md"
    )
  end

  test "returns a position for every item" do
    items = [item("alpha", ["beta"]), item("beta"), item("gamma")]

    %{positions: positions} = GraphLayout.layout(items, @geometry)

    assert Map.keys(positions) |> Enum.sort() == ["alpha", "beta", "gamma"]
  end

  test "layout is deterministic for the same input" do
    items = [item("alpha", ["beta", "gamma"]), item("beta", ["gamma"]), item("gamma")]

    result_a = GraphLayout.layout(items, @geometry)
    result_b = GraphLayout.layout(items, @geometry)

    assert result_a == result_b
  end

  test "edges are deduplicated and undirected regardless of link direction" do
    items = [item("alpha", ["beta"]), item("beta", ["alpha"]), item("gamma")]

    %{edges: edges} = GraphLayout.layout(items, @geometry)

    assert edges == [{"alpha", "beta"}]
  end

  test "edges_from/1 ignores related ids with no matching item" do
    items = [item("alpha", ["beta", "does-not-exist"]), item("beta")]

    assert GraphLayout.edges_from(items) == [{"alpha", "beta"}]
  end

  test "all positions stay within the canvas bounds" do
    items = for n <- 1..12, do: item("item-#{n}", ["item-#{rem(n, 12) + 1}"])

    %{positions: positions} = GraphLayout.layout(items, @geometry)

    assert Enum.all?(positions, fn {_id, %{x: x, y: y}} ->
             x >= 0 and x <= @geometry.width and y >= 0 and y <= @geometry.height
           end)
  end
end
