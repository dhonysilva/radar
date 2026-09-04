defmodule Radar.TechRadar.FrontMatterWriterTest do
  use ExUnit.Case, async: true

  alias Radar.TechRadar.{FrontMatterParser, FrontMatterWriter}

  test "render/2 output round-trips through FrontMatterParser.parse/2" do
    attrs = %{
      title: "React",
      ring: :adopt,
      quadrant: :"languages-and-frameworks",
      tags: ["frontend", "coding"],
      featured: true,
      related: ["typescript", "nextjs"],
      type: "Radar Item",
      status: :stable,
      stale_after: "2026-12-31",
      sources: ["https://example.com/a", "https://example.com/b"]
    }

    body = "**React** is a UI library.\n\nWe use it everywhere."

    content = FrontMatterWriter.render(attrs, body)
    assert {parsed, parsed_body} = FrontMatterParser.parse("item.md", content)

    assert parsed.title == "React"
    assert parsed.ring == "adopt"
    assert parsed.quadrant == "languages-and-frameworks"
    assert parsed.tags == ["frontend", "coding"]
    assert parsed.featured == true
    assert parsed.related == ["typescript", "nextjs"]
    assert parsed.type == "Radar Item"
    assert parsed.status == "stable"
    assert parsed.stale_after == "2026-12-31"
    assert parsed.sources == ["https://example.com/a", "https://example.com/b"]
    assert parsed_body == "\n" <> body <> "\n"
  end

  test "render/2 omits blank/empty optional fields entirely" do
    attrs = %{
      title: "X",
      ring: :hold,
      quadrant: :tools,
      tags: [],
      featured: false,
      related: [],
      type: "Radar Item",
      status: :stable,
      stale_after: nil,
      sources: []
    }

    content = FrontMatterWriter.render(attrs, "Body.")
    assert {parsed, _body} = FrontMatterParser.parse("item.md", content)

    refute Map.has_key?(parsed, :tags)
    refute Map.has_key?(parsed, :related)
    refute Map.has_key?(parsed, :stale_after)
    refute Map.has_key?(parsed, :sources)
    assert parsed.featured == false
  end
end
