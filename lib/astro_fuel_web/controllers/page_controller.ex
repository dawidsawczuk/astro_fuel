defmodule AstroFuelWeb.PageController do
  use AstroFuelWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
