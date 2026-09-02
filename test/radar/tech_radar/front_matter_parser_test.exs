defmodule Radar.TechRadar.FrontMatterParserTest do
  use ExUnit.Case, async: true

  alias Radar.TechRadar.FrontMatterParser

  test "parses quoted strings, bare words, lists, and booleans" do
    contents = """
    ---
    title: "React"
    ring: adopt
    quadrant: languages-and-frameworks
    tags: [frontend, coding]
    featured: true
    ---
    Body **markdown**.
    """

    assert {attrs, body} = FrontMatterParser.parse("item.md", contents)

    assert attrs == %{
             title: "React",
             ring: "adopt",
             quadrant: "languages-and-frameworks",
             tags: ["frontend", "coding"],
             featured: true
           }

    assert body == "Body **markdown**.\n"
  end

  test "parses the related field as a list of slugs" do
    contents = """
    ---
    title: "X"
    ring: hold
    quadrant: tools
    related: [alpha, beta]
    ---
    Body.
    """

    assert {%{related: ["alpha", "beta"]}, _body} = FrontMatterParser.parse("item.md", contents)
  end

  test "parses a bracketed list with irregular spacing" do
    contents = """
    ---
    title: "X"
    ring: hold
    quadrant: tools
    tags: [ a,b ,c ]
    ---
    Body.
    """

    assert {%{tags: ["a", "b", "c"]}, _body} = FrontMatterParser.parse("item.md", contents)
  end

  test "defaults are absent when a field is omitted" do
    contents = """
    ---
    title: "X"
    ring: hold
    quadrant: tools
    ---
    Body.
    """

    assert {attrs, _body} = FrontMatterParser.parse("item.md", contents)
    refute Map.has_key?(attrs, :featured)
    refute Map.has_key?(attrs, :tags)
  end

  test "raises when there is no closing delimiter" do
    contents = """
    ---
    title: "X"
    Body without closing delimiter.
    """

    assert_raise RuntimeError, ~r/missing or malformed front matter/, fn ->
      FrontMatterParser.parse("item.md", contents)
    end
  end

  test "raises on an unknown front matter key" do
    contents = """
    ---
    title: "X"
    bogus: nope
    ---
    Body.
    """

    assert_raise RuntimeError, ~r/unknown front matter key/, fn ->
      FrontMatterParser.parse("item.md", contents)
    end
  end
end
