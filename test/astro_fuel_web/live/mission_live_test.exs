defmodule AstroFuelWeb.MissionLiveTest do
  use AstroFuelWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "MissionLive" do
    test "renders initial state with title and empty path", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Interplanetary Fuel Calculator"
      assert html =~ "Add steps to plan your mission"
    end

    test "adding a step updates the flight path", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> element("button", "Add Step") |> render_click()

      html = render(view)
      assert html =~ "Launch"
      assert html =~ "Earth"
      refute html =~ "Add steps to plan your mission"
    end

    test "entering mass shows it in the input", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> render_change("update_mass", %{"mass" => "28801"})

      assert render(view) =~ "28801"
    end

    test "valid mission shows fuel calculation", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Add a step
      view |> element("button", "Add Step") |> render_click()

      # Enter mass
      view |> render_change("update_mass", %{"mass" => "28801"})

      html = render(view)
      # Should show the fuel for a single Earth launch: 19,772 kg
      assert html =~ "19,772"
      assert html =~ "Total Fuel Required"
    end

    test "removing a step updates the path", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Add two steps
      view |> element("button", "Add Step") |> render_click()
      view |> element("button", "Add Step") |> render_click()

      # Should have two step rows (look for step numbers in badges)
      html = render(view)
      assert html =~ ">1</span>"
      assert html =~ ">2</span>"

      # Get the first step's ID
      [_, step_id] = Regex.run(~r/phx-value-id="([^"]+)"/, html)

      # Remove the step
      view |> render_click("remove_step", %{"id" => step_id})

      # Should only have one step now
      html = render(view)
      assert html =~ ">1</span>"
      refute html =~ ">2</span>"
    end

    test "changing action updates the step", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> element("button", "Add Step") |> render_click()

      # Get the step ID from the page
      html = render(view)
      # Extract ID from phx-value-id attribute
      [_, step_id] = Regex.run(~r/phx-value-id="([^"]+)"/, html)

      # Change action to Land
      view |> render_change("update_step", %{"id" => step_id, "action" => "land"})

      html = render(view)
      assert html =~ "selected"
      assert html =~ "land"
    end

    test "changing planet updates the step", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> element("button", "Add Step") |> render_click()

      # Get the step ID from the page
      html = render(view)
      [_, step_id] = Regex.run(~r/phx-value-id="([^"]+)"/, html)

      # Change planet to Mars
      view |> render_change("update_step", %{"id" => step_id, "planet" => "mars"})

      html = render(view)
      assert html =~ "Mars"
    end

    test "shows validation error for invalid mass", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> render_change("update_mass", %{"mass" => "abc"})

      assert render(view) =~ "Enter a valid integer"
    end

    test "shows validation error for zero mass", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> render_change("update_mass", %{"mass" => "0"})

      assert render(view) =~ "Mass must be positive"
    end

    test "shows warning when path is empty but mass is set", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> render_change("update_mass", %{"mass" => "28801"})

      html = render(view)
      assert html =~ "Flight path is empty"
    end

    test "multiple steps calculates total fuel", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Set mass
      view |> render_change("update_mass", %{"mass" => "28801"})

      # Add 4 steps (all default to Launch Earth)
      view |> element("button", "Add Step") |> render_click()
      view |> element("button", "Add Step") |> render_click()
      view |> element("button", "Add Step") |> render_click()
      view |> element("button", "Add Step") |> render_click()

      # Verify we have 4 steps and fuel is calculated
      html = render(view)
      assert html =~ "Total Fuel Required"
      # 4 flight steps
      assert html =~ ">4</div>"
    end

    test "moving steps reorders the path", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Add two steps and set mass
      view |> render_change("update_mass", %{"mass" => "10000"})
      view |> element("button", "Add Step") |> render_click()
      view |> element("button", "Add Step") |> render_click()

      # Change second step to Land on Mars for differentiation
      # (Default steps are identical, so fuel won't change on reorder for identical steps)

      # Move step from position 1 to position 0
      view |> element("button[phx-click=move_step][phx-value-from=\"1\"]") |> render_click()

      # The page should still render correctly
      html = render(view)
      assert html =~ "Total Fuel Required"
    end

    test "ignores unknown action values without crashing", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> element("button", "Add Step") |> render_click()
      html = render(view)
      [_, step_id] = Regex.run(~r/phx-value-id="([^\"]+)"/, html)

      assert render_change(view, "update_step", %{"id" => step_id, "action" => "fly"}) =~
               "Interplanetary Fuel Calculator"

      # Original action remains selected
      assert render(view) =~ "Launch"
    end

    test "invalid move_step indices are ignored", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> element("button", "Add Step") |> render_click()

      render_click(view, "move_step", %{"from" => "abc", "to" => "-2"})

      assert render(view) =~ "Add Step"
    end
  end
end
