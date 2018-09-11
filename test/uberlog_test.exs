defmodule UberlogTest do
  use ExUnit.Case
  doctest Uberlog

  test "greets the world" do
    assert Uberlog.hello() == :world
  end
end
