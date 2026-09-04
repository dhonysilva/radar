defmodule RadarWeb.RadarLive.EditTest do
  use RadarWeb.ConnCase

  @gamma_path "test/support/fixtures/radar/releases/2024-06-01/gamma.md"

  setup do
    original = File.read!(@gamma_path)
    on_exit(fn -> File.write!(@gamma_path, original) end)
    :ok
  end

  test "renders the edit form pre-filled with the item's current values", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/radar/beta/edit")

    assert html =~ ~s(value="Beta")
    assert html =~ "Playbook"
    assert html =~ "https://example.com/postmortem"
    assert html =~ "Beta body, only ever released once."
  end

  test "redirects to the radar index with a flash for an unknown id", %{conn: conn} do
    assert {:error, {:live_redirect, %{to: to, flash: flash}}} =
             live(conn, ~p"/radar/does-not-exist/edit")

    assert to == ~p"/radar"
    assert flash["error"] =~ "couldn't be found"
  end

  test "submitting valid changes writes the file and redirects to the show page", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/radar/gamma/edit")

    assert {:error, {:live_redirect, %{to: to}}} =
             view
             |> form("#item-form",
               item: %{"tags" => "testing, new, updated", "body" => "Updated gamma body."}
             )
             |> render_submit()

    assert to == ~p"/radar/gamma"

    content = File.read!(@gamma_path)
    assert content =~ "tags: [testing, new, updated]"
    assert content =~ "Updated gamma body."
  end

  test "submitting an unknown related id shows an error and does not save", %{conn: conn} do
    original = File.read!(@gamma_path)
    {:ok, view, _html} = live(conn, ~p"/radar/gamma/edit")

    html =
      view
      |> form("#item-form", item: %{"related" => "does-not-exist"})
      |> render_submit()

    assert html =~ "unknown item ids"
    assert File.read!(@gamma_path) == original
  end

  test "submitting a malformed stale_after date shows an error and does not save", %{conn: conn} do
    original = File.read!(@gamma_path)
    {:ok, view, _html} = live(conn, ~p"/radar/gamma/edit")

    html =
      view
      |> form("#item-form", item: %{"stale_after" => "not-a-date"})
      |> render_submit()

    assert html =~ "valid date"
    assert File.read!(@gamma_path) == original
  end
end
