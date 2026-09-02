defmodule Radar.TechRadar.ReleaseTest do
  use ExUnit.Case, async: true

  alias Radar.TechRadar.Release

  @path "priv/radar/releases/2024-01-01/item.md"

  defp attrs(overrides \\ %{}) do
    Map.merge(
      %{title: "Item", ring: "adopt", quadrant: "techniques"},
      overrides
    )
  end

  test "type defaults to \"Radar Item\", status to :stable, stale_after to nil, sources to []" do
    release = Release.build(@path, attrs(), "<p>body</p>")

    assert release.type == "Radar Item"
    assert release.status == :stable
    assert release.stale_after == nil
    assert release.sources == []
  end

  test "explicit type, status, stale_after, and sources round-trip" do
    release =
      Release.build(
        @path,
        attrs(%{
          type: "Playbook",
          status: "deprecated",
          stale_after: "2026-12-31",
          sources: ["https://example.com/a"]
        }),
        "<p>body</p>"
      )

    assert release.type == "Playbook"
    assert release.status == :deprecated
    assert release.stale_after == ~D[2026-12-31]
    assert release.sources == ["https://example.com/a"]
  end

  test "raises on an unknown status" do
    assert_raise RuntimeError, ~r/unknown status/, fn ->
      Release.build(@path, attrs(%{status: "bogus"}), "<p>body</p>")
    end
  end

  test "raises on a malformed stale_after date" do
    assert_raise RuntimeError, ~r/invalid stale_after date/, fn ->
      Release.build(@path, attrs(%{stale_after: "not-a-date"}), "<p>body</p>")
    end
  end
end
