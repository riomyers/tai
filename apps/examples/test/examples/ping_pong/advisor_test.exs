defmodule Examples.PingPong.AdvisorTest do
  use Tai.TestSupport.E2ECase, async: false

  @scenario :ping_pong

  def before_app_start, do: seed_mock_responses(@scenario)

  def after_app_start do
    configure_advisor_group(@scenario)
    start_advisors(where: [group_id: @scenario])
  end

  test "places a passive order inside the current quote and flips it upon fill" do
    push_stream_market_data({@scenario, :snapshot, :test_exchange_a, :xbtusd})

    assert_receive {Tai.Event, %Tai.Events.OrderUpdated{status: :open} = maker_open, _}
    assert maker_open.price == Decimal.new(5500)
    assert maker_open.qty == Decimal.new(1)
  end
end
