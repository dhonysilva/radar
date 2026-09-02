defmodule Radar.TechRadar.ItemBuilderTest do
  use ExUnit.Case, async: true

  alias Radar.TechRadar.{ItemBuilder, Release}

  defp release(attrs) do
    defaults = %{
      title: "Item",
      tags: [],
      featured: true,
      related: [],
      type: "Radar Item",
      status: :stable,
      stale_after: nil,
      sources: [],
      body_html: "<p>body</p>",
      path: "priv/radar/releases/x/item.md"
    }

    struct!(Release, Map.merge(defaults, Map.new(attrs)))
  end

  test "an item released only in the latest release is flagged :new" do
    releases = [
      release(id: "alpha", date: ~D[2024-06-01], ring: :adopt, quadrant: :tools)
    ]

    [item] = ItemBuilder.from_releases(releases)

    assert item.flag == :new
    assert item.history == []
    assert item.ring == :adopt
  end

  test "an item released only in an older release is not flagged :new" do
    releases = [
      release(id: "alpha", date: ~D[2024-01-01], ring: :adopt, quadrant: :tools),
      release(id: "beta", date: ~D[2024-06-01], ring: :trial, quadrant: :tools)
    ]

    items = ItemBuilder.from_releases(releases)
    alpha = Enum.find(items, &(&1.id == "alpha"))

    assert alpha.flag == nil
  end

  test "an item whose ring changed between releases is flagged :changed" do
    releases = [
      release(id: "alpha", date: ~D[2024-01-01], ring: :trial, quadrant: :techniques),
      release(id: "alpha", date: ~D[2024-06-01], ring: :adopt, quadrant: :techniques)
    ]

    [item] = ItemBuilder.from_releases(releases)

    assert item.flag == :changed
    assert item.ring == :adopt
    assert item.history == [%{release_date: ~D[2024-01-01], ring: :trial}]
  end

  test "an item whose ring stayed the same across releases has no flag" do
    releases = [
      release(id: "alpha", date: ~D[2024-01-01], ring: :adopt, quadrant: :techniques),
      release(id: "alpha", date: ~D[2024-06-01], ring: :adopt, quadrant: :techniques)
    ]

    [item] = ItemBuilder.from_releases(releases)

    assert item.flag == nil
  end

  test "an item's related list comes from its latest release" do
    releases = [
      release(
        id: "alpha",
        date: ~D[2024-01-01],
        ring: :trial,
        quadrant: :techniques,
        related: []
      ),
      release(
        id: "alpha",
        date: ~D[2024-06-01],
        ring: :adopt,
        quadrant: :techniques,
        related: ["beta"]
      )
    ]

    [item] = ItemBuilder.from_releases(releases)

    assert item.related == ["beta"]
  end

  test "an item's type, status, stale_after, and sources come from its latest release" do
    releases = [
      release(
        id: "alpha",
        date: ~D[2024-01-01],
        ring: :trial,
        quadrant: :techniques,
        type: "Radar Item",
        status: :draft,
        stale_after: nil,
        sources: []
      ),
      release(
        id: "alpha",
        date: ~D[2024-06-01],
        ring: :adopt,
        quadrant: :techniques,
        type: "Playbook",
        status: :deprecated,
        stale_after: ~D[2026-01-01],
        sources: ["https://example.com/source"]
      )
    ]

    [item] = ItemBuilder.from_releases(releases)

    assert item.type == "Playbook"
    assert item.status == :deprecated
    assert item.stale_after == ~D[2026-01-01]
    assert item.sources == ["https://example.com/source"]
  end

  test "history is ordered ascending by release date" do
    releases = [
      release(id: "alpha", date: ~D[2024-01-01], ring: :assess, quadrant: :techniques),
      release(id: "alpha", date: ~D[2024-03-01], ring: :trial, quadrant: :techniques),
      release(id: "alpha", date: ~D[2024-06-01], ring: :adopt, quadrant: :techniques)
    ]

    [item] = ItemBuilder.from_releases(releases)

    assert item.history == [
             %{release_date: ~D[2024-01-01], ring: :assess},
             %{release_date: ~D[2024-03-01], ring: :trial}
           ]
  end
end
