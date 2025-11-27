defmodule AstroFuelWeb.PageControllerTest do
  use AstroFuelWeb.ConnCase

  test "GET / renders fuel calculator", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Interplanetary Fuel Calculator"
  end
end
