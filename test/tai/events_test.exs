defmodule Tai.EventsTest do
  use ExUnit.Case, async: false

  defmodule MyEvent do
    defstruct []
  end

  defmodule MyOtherEvent do
    defstruct []
  end

  describe ".subscribe/1" do
    test "creates a registry entry for all events of the given type" do
      event = %MyEvent{}
      other_event = %MyOtherEvent{}
      start_supervised!({Tai.Events, 1})

      Tai.Events.subscribe(MyEvent)

      Registry.dispatch(Tai.Events, MyEvent, fn entries ->
        for {pid, _} <- entries, do: send(pid, event)
      end)

      Registry.dispatch(Tai.Events, MyOtherEvent, fn entries ->
        for {pid, _} <- entries, do: send(pid, other_event)
      end)

      assert_receive %MyEvent{}
      refute_receive %MyOtherEvent{}
    end
  end

  describe ".broadcast/1" do
    test "sends the event to all subscribers of the event type" do
      event = %MyEvent{}
      other_event = %MyOtherEvent{}
      start_supervised!({Tai.Events, 1})

      Registry.register(Tai.Events, MyEvent, [])

      Tai.Events.broadcast(event)
      Tai.Events.broadcast(other_event)

      assert_receive %MyEvent{}
      refute_receive %MyOtherEvent{}
    end
  end
end
