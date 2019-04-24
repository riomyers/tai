defmodule Tai.VenueAdapters.Gdax.OrderBookFeedTest do
  use ExUnit.Case
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney
  doctest Tai.VenueAdapters.Gdax.OrderBookFeed

  import ExUnit.CaptureLog

  def send_feed_l2update(pid, product_id, changes) do
    Tai.WebSocket.send_json_msg(pid, %{
      type: "l2update",
      time: Timex.now() |> DateTime.to_string(),
      product_id: product_id,
      changes: changes
    })
  end

  def send_feed_snapshot(pid, product_id, bids, asks) do
    Tai.WebSocket.send_json_msg(pid, %{
      type: "snapshot",
      product_id: product_id,
      bids: bids,
      asks: asks
    })
  end

  def send_subscriptions(pid, product_ids) do
    Tai.WebSocket.send_json_msg(pid, %{
      type: "subscriptions",
      channels: [
        %{
          product_ids: product_ids,
          name: "level2"
        }
      ]
    })
  end

  setup do
    on_exit(fn ->
      Application.stop(:tai)
    end)

    {:ok, _} = Application.ensure_all_started(:tai)
    HTTPoison.start()
    Process.register(self(), :test)

    my_gdax_feed_btc_usd_pid =
      start_supervised!(
        {Tai.Markets.OrderBook, [feed_id: :my_gdax_feed, symbol: :btc_usd]},
        id: :my_gdax_feed_btc_usd
      )

    my_gdax_feed_ltc_usd_pid =
      start_supervised!(
        {Tai.Markets.OrderBook, [feed_id: :my_gdax_feed, symbol: :ltc_usd]},
        id: :my_gdax_feed_ltc_usd
      )

    my_feed_b_btc_usd_pid =
      start_supervised!(
        {Tai.Markets.OrderBook, [feed_id: :my_feed_b, symbol: :btc_usd]},
        id: :my_feed_b_btc_usd
      )

    {:ok, my_gdax_feed_pid} =
      use_cassette "venue_adapters/gdax/order_book_feed" do
        Tai.VenueAdapters.Gdax.OrderBookFeed.start_link(
          "ws://localhost:#{EchoBoy.Config.port()}/ws",
          feed_id: :my_gdax_feed,
          symbols: [:btc_usd, :ltc_usd]
        )
      end

    Tai.Markets.OrderBook.replace(%Tai.Markets.OrderBook{
      venue_id: :my_gdax_feed,
      product_symbol: :btc_usd,
      bids: %{
        1.0 => {1.1, nil, nil},
        1.1 => {1.0, nil, nil}
      },
      asks: %{
        1.2 => {0.1, nil, nil},
        1.3 => {0.11, nil, nil}
      }
    })

    Tai.Markets.OrderBook.replace(%Tai.Markets.OrderBook{
      venue_id: :my_gdax_feed,
      product_symbol: :ltc_usd,
      bids: %{100.0 => {0.1, nil, nil}},
      asks: %{100.1 => {0.1, nil, nil}}
    })

    Tai.Markets.OrderBook.replace(%Tai.Markets.OrderBook{
      venue_id: :my_feed_b,
      product_symbol: :btc_usd,
      bids: %{1.0 => {1.1, nil, nil}},
      asks: %{1.2 => {0.1, nil, nil}}
    })

    start_supervised!({
      Support.ForwardOrderBookEvents,
      [feed_id: :my_gdax_feed, symbol: :btc_usd]
    })

    {
      :ok,
      %{
        my_gdax_feed_pid: my_gdax_feed_pid,
        my_gdax_feed_btc_usd_pid: my_gdax_feed_btc_usd_pid,
        my_gdax_feed_ltc_usd_pid: my_gdax_feed_ltc_usd_pid,
        my_feed_b_btc_usd_pid: my_feed_b_btc_usd_pid
      }
    }
  end

  test("snapshot replaces the bids/asks in the order book for the symbol", %{
    my_gdax_feed_pid: my_gdax_feed_pid,
    my_gdax_feed_btc_usd_pid: my_gdax_feed_btc_usd_pid,
    my_gdax_feed_ltc_usd_pid: my_gdax_feed_ltc_usd_pid,
    my_feed_b_btc_usd_pid: my_feed_b_btc_usd_pid
  }) do
    send_feed_snapshot(my_gdax_feed_pid, "BTC-USD", [["110.0", "100.0"], ["100.0", "110.0"]], [
      ["120.0", "10.0"],
      ["130.0", "11.0"]
    ])

    assert_receive {:order_book_snapshot, :my_gdax_feed, :btc_usd, %Tai.Markets.OrderBook{}}

    {:ok, %Tai.Markets.OrderBook{bids: bids, asks: asks}} =
      Tai.Markets.OrderBook.quotes(my_gdax_feed_btc_usd_pid)

    [
      %Tai.Markets.PriceLevel{price: 110.0, size: 100.0, server_changed_at: nil} = bid_a,
      %Tai.Markets.PriceLevel{price: 100.0, size: 110.0, server_changed_at: nil} = bid_b
    ] = bids

    [
      %Tai.Markets.PriceLevel{price: 120.0, size: 10.0, server_changed_at: nil} = ask_a,
      %Tai.Markets.PriceLevel{price: 130.0, size: 11.0, server_changed_at: nil} = ask_b
    ] = asks

    assert DateTime.compare(bid_a.processed_at, bid_b.processed_at)
    assert DateTime.compare(bid_a.processed_at, ask_a.processed_at)
    assert DateTime.compare(bid_a.processed_at, ask_b.processed_at)

    assert Tai.Markets.OrderBook.quotes(my_gdax_feed_ltc_usd_pid) == {
             :ok,
             %Tai.Markets.OrderBook{
               venue_id: :my_gdax_feed,
               product_symbol: :ltc_usd,
               bids: [
                 %Tai.Markets.PriceLevel{
                   price: 100.0,
                   size: 0.1,
                   processed_at: nil,
                   server_changed_at: nil
                 }
               ],
               asks: [
                 %Tai.Markets.PriceLevel{
                   price: 100.1,
                   size: 0.1,
                   processed_at: nil,
                   server_changed_at: nil
                 }
               ]
             }
           }

    assert Tai.Markets.OrderBook.quotes(my_feed_b_btc_usd_pid) == {
             :ok,
             %Tai.Markets.OrderBook{
               venue_id: :my_feed_b,
               product_symbol: :btc_usd,
               bids: [
                 %Tai.Markets.PriceLevel{
                   price: 1.0,
                   size: 1.1,
                   processed_at: nil,
                   server_changed_at: nil
                 }
               ],
               asks: [
                 %Tai.Markets.PriceLevel{
                   price: 1.2,
                   size: 0.1,
                   processed_at: nil,
                   server_changed_at: nil
                 }
               ]
             }
           }
  end

  test("l2update adds/updates/deletes the bids/asks in the order book for the symbol", %{
    my_gdax_feed_pid: my_gdax_feed_pid,
    my_gdax_feed_btc_usd_pid: my_gdax_feed_btc_usd_pid,
    my_gdax_feed_ltc_usd_pid: my_gdax_feed_ltc_usd_pid,
    my_feed_b_btc_usd_pid: my_feed_b_btc_usd_pid
  }) do
    send_feed_l2update(my_gdax_feed_pid, "BTC-USD", [
      ["buy", "0.9", "0.1"],
      ["sell", "1.4", "0.12"],
      ["buy", "1.0", "1.2"],
      ["sell", "1.2", "0.11"],
      ["buy", "1.1", "0"],
      ["sell", "1.3", "0.0"]
    ])

    assert_receive {:order_book_changes, :my_gdax_feed, :btc_usd, %Tai.Markets.OrderBook{}}

    {:ok, %Tai.Markets.OrderBook{bids: bids, asks: asks}} =
      Tai.Markets.OrderBook.quotes(my_gdax_feed_btc_usd_pid)

    [
      %Tai.Markets.PriceLevel{price: 1.0, size: 1.2} = bid_a,
      %Tai.Markets.PriceLevel{price: 0.9, size: 0.1} = bid_b
    ] = bids

    [
      %Tai.Markets.PriceLevel{price: 1.2, size: 0.11} = ask_a,
      %Tai.Markets.PriceLevel{price: 1.4, size: 0.12} = ask_b
    ] = asks

    assert DateTime.compare(bid_a.processed_at, bid_b.processed_at)
    assert DateTime.compare(bid_a.processed_at, ask_a.processed_at)
    assert DateTime.compare(bid_a.processed_at, ask_b.processed_at)
    assert DateTime.compare(bid_a.server_changed_at, bid_b.server_changed_at)
    assert DateTime.compare(bid_a.server_changed_at, ask_a.server_changed_at)
    assert DateTime.compare(bid_a.server_changed_at, ask_b.server_changed_at)

    assert Tai.Markets.OrderBook.quotes(my_gdax_feed_ltc_usd_pid) == {
             :ok,
             %Tai.Markets.OrderBook{
               venue_id: :my_gdax_feed,
               product_symbol: :ltc_usd,
               bids: [
                 %Tai.Markets.PriceLevel{
                   price: 100.0,
                   size: 0.1,
                   processed_at: nil,
                   server_changed_at: nil
                 }
               ],
               asks: [
                 %Tai.Markets.PriceLevel{
                   price: 100.1,
                   size: 0.1,
                   processed_at: nil,
                   server_changed_at: nil
                 }
               ]
             }
           }

    assert Tai.Markets.OrderBook.quotes(my_feed_b_btc_usd_pid) == {
             :ok,
             %Tai.Markets.OrderBook{
               venue_id: :my_feed_b,
               product_symbol: :btc_usd,
               bids: [
                 %Tai.Markets.PriceLevel{
                   price: 1.0,
                   size: 1.1,
                   processed_at: nil,
                   server_changed_at: nil
                 }
               ],
               asks: [
                 %Tai.Markets.PriceLevel{
                   price: 1.2,
                   size: 0.1,
                   processed_at: nil,
                   server_changed_at: nil
                 }
               ]
             }
           }
  end

  test "logs an info message for successful product subscriptions", %{
    my_gdax_feed_pid: my_gdax_feed_pid
  } do
    log_msg =
      capture_log(fn ->
        send_subscriptions(my_gdax_feed_pid, ["BTC-USD", "LTC-USD"])
        :timer.sleep(100)
      end)

    assert log_msg =~ "[info]  successfully subscribed to [\"BTC-USD\", \"LTC-USD\"]"
  end

  test "logs a warning for unhandled messages", %{my_gdax_feed_pid: my_gdax_feed_pid} do
    log_msg =
      capture_log(fn ->
        Tai.WebSocket.send_json_msg(my_gdax_feed_pid, %{type: "unknown_type"})
        :timer.sleep(100)
      end)

    assert log_msg =~ "[warn]  unhandled message: %{\"type\" => \"unknown_type\"}"
  end
end
