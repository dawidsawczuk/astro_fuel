defmodule AstroFuel.FlightStepTest do
  use ExUnit.Case, async: true
  doctest AstroFuel.FlightStep

  alias AstroFuel.FlightStep

  describe "new/3" do
    test "creates a valid launch step" do
      assert {:ok, step} = FlightStep.new(:launch, :earth)
      assert step.action == :launch
      assert step.planet == :earth
      assert is_binary(step.id)
      assert byte_size(step.id) > 0
    end

    test "creates a valid land step" do
      assert {:ok, step} = FlightStep.new(:land, :moon)
      assert step.action == :land
      assert step.planet == :moon
    end

    test "accepts custom ID" do
      assert {:ok, step} = FlightStep.new(:launch, :mars, id: "custom_id_123")
      assert step.id == "custom_id_123"
    end

    test "generates unique IDs for different steps" do
      {:ok, step1} = FlightStep.new(:launch, :earth)
      {:ok, step2} = FlightStep.new(:launch, :earth)
      assert step1.id != step2.id
    end

    test "returns error for invalid action" do
      assert {:error, :invalid_action} = FlightStep.new(:hover, :earth)
      assert {:error, :invalid_action} = FlightStep.new(:orbit, :mars)
      assert {:error, :invalid_action} = FlightStep.new("launch", :earth)
    end

    test "returns error for unknown planet" do
      assert {:error, :unknown_planet} = FlightStep.new(:launch, :pluto)
      assert {:error, :unknown_planet} = FlightStep.new(:land, :jupiter)
      assert {:error, :unknown_planet} = FlightStep.new(:launch, "earth")
    end
  end

  describe "actions/0" do
    test "returns list of valid actions" do
      actions = FlightStep.actions()
      assert :launch in actions
      assert :land in actions
      assert length(actions) == 2
    end
  end

  describe "valid_action?/1" do
    test "returns true for valid actions" do
      assert FlightStep.valid_action?(:launch)
      assert FlightStep.valid_action?(:land)
    end

    test "returns false for invalid actions" do
      refute FlightStep.valid_action?(:hover)
      refute FlightStep.valid_action?(:orbit)
      refute FlightStep.valid_action?("launch")
    end
  end
end
