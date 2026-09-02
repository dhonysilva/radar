defmodule Radar.TechRadarTest do
  use ExUnit.Case, async: true

  alias Radar.TechRadar

  test "list_items/0 returns every item, merged across releases, sorted by title" do
    items = TechRadar.list_items()

    assert Enum.map(items, & &1.title) == ["Alpha", "Beta", "Gamma"]
  end

  test "an item that changed rings carries its history and :changed flag" do
    assert {:ok, alpha} = TechRadar.get_item("alpha")

    assert alpha.ring == :adopt
    assert alpha.flag == :changed
    assert alpha.history == [%{release_date: ~D[2024-01-01], ring: :trial}]
  end

  test "an item's related ids resolve to real items" do
    assert {:ok, alpha} = TechRadar.get_item("alpha")
    assert alpha.related == ["beta"]

    assert Enum.all?(alpha.related, &match?({:ok, _}, TechRadar.get_item(&1)))
  end

  test "an item only in the latest release is flagged :new" do
    assert {:ok, gamma} = TechRadar.get_item("gamma")

    assert gamma.flag == :new
    assert gamma.history == []
  end

  test "get_item/1 returns :error for an unknown id" do
    assert TechRadar.get_item("does-not-exist") == :error
  end

  test "list_quadrants/0, list_rings/0, and list_flags/0 return the configured values" do
    assert length(TechRadar.list_quadrants()) == 4
    assert length(TechRadar.list_rings()) == 4
    assert length(TechRadar.list_flags()) == 3
  end

  test "list_tags/0 returns every tag used by at least one item, sorted" do
    assert TechRadar.list_tags() == ["legacy", "new", "testing"]
  end

  test "filter_items/2 filters by quadrant, ring, tag, and query" do
    items = TechRadar.list_items()

    assert TechRadar.filter_items(items, %{"quadrant" => "techniques"}) |> Enum.map(& &1.id) ==
             ["alpha"]

    assert TechRadar.filter_items(items, %{"ring" => "adopt"}) |> Enum.map(& &1.id) == ["alpha"]

    assert TechRadar.filter_items(items, %{"tag" => "legacy"}) |> Enum.map(& &1.id) == ["beta"]

    assert TechRadar.filter_items(items, %{"query" => "gam"}) |> Enum.map(& &1.id) == ["gamma"]
  end

  test "filter_items/2 with no filters returns every item" do
    items = TechRadar.list_items()

    assert TechRadar.filter_items(items, %{}) == items
  end

  test "about_html/0 renders the about markdown to sanitized HTML" do
    assert TechRadar.about_html() =~ "About fixture"
  end
end
