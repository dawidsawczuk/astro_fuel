defmodule AstroFuelWeb.Router do
  use AstroFuelWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {AstroFuelWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", AstroFuelWeb do
    pipe_through :browser

    live "/", MissionLive, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", AstroFuelWeb do
  #   pipe_through :api
  # end
end
