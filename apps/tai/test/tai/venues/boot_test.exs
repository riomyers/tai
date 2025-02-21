defmodule Tai.Venues.BootTest do
  use ExUnit.Case, async: false
  doctest Tai.Venues.Boot

  setup_all do
    start_supervised!(Tai.TestSupport.Mocks.Server)
    :ok
  end

  setup do
    on_exit(fn ->
      Application.stop(:tai)
    end)

    {:ok, _} = Application.ensure_all_started(:tai)
    :ok
  end

  @venue_id :mock_boot
  @account_id :main
  @timeout 5000

  describe ".run success" do
    setup [:mock_products, :mock_asset_balances, :mock_maker_taker_fees]

    @adapter struct(Tai.Venues.Adapter, %{
               id: @venue_id,
               adapter: Tai.VenueAdapters.Mock,
               products: "* -ltc_usdt",
               accounts: %{main: %{}},
               timeout: @timeout
             })

    test "hydrates filtered products" do
      assert {:ok, %Tai.Venues.Adapter{}} = Tai.Venues.Boot.run(@adapter)

      assert {:ok, btc_usdt_product} = Tai.Venues.ProductStore.find({@venue_id, :btc_usdt})
      assert {:ok, eth_usdt_product} = Tai.Venues.ProductStore.find({@venue_id, :eth_usdt})
      assert {:error, :not_found} = Tai.Venues.ProductStore.find({@venue_id, :ltc_usdt})
    end

    test "hydrates asset balances" do
      assert {:ok, %Tai.Venues.Adapter{}} = Tai.Venues.Boot.run(@adapter)

      assert {:ok, btc_balance} =
               Tai.Venues.AssetBalances.find_by(
                 venue_id: @venue_id,
                 account_id: @account_id,
                 asset: :btc
               )

      assert {:ok, eth_balance} =
               Tai.Venues.AssetBalances.find_by(
                 venue_id: @venue_id,
                 account_id: @account_id,
                 asset: :eth
               )

      assert {:ok, ltc_balance} =
               Tai.Venues.AssetBalances.find_by(
                 venue_id: @venue_id,
                 account_id: @account_id,
                 asset: :ltc
               )

      assert {:ok, usdt_balance} =
               Tai.Venues.AssetBalances.find_by(
                 venue_id: @venue_id,
                 account_id: :main,
                 asset: :usdt
               )
    end

    test "hydrates fees" do
      assert {:ok, %Tai.Venues.Adapter{}} = Tai.Venues.Boot.run(@adapter)

      assert {:ok, btc_usdt_fee} =
               Tai.Venues.FeeStore.find_by(
                 venue_id: @venue_id,
                 account_id: @account_id,
                 symbol: :btc_usdt
               )

      assert {:ok, eth_usdt_fee} =
               Tai.Venues.FeeStore.find_by(
                 venue_id: @venue_id,
                 account_id: @account_id,
                 symbol: :eth_usdt
               )

      assert {:error, :not_found} =
               Tai.Venues.FeeStore.find_by(
                 venue_id: @venue_id,
                 account_id: @account_id,
                 symbol: :ltc_usdt
               )
    end
  end

  describe ".run products hydrate error" do
    test "returns an error tuple" do
      adapter =
        struct(Tai.Venues.Adapter, %{
          id: :mock_boot,
          adapter: Tai.VenueAdapters.Mock,
          products: "*",
          accounts: %{},
          timeout: @timeout
        })

      assert {:error, result} = Tai.Venues.Boot.run(adapter)
      assert {result_adapter, reasons} = result
      assert result_adapter == adapter
      assert reasons == [products: :mock_response_not_found]
    end
  end

  describe ".run asset balances hydrate error" do
    setup [:mock_products, :mock_maker_taker_fees]

    test "returns an error" do
      adapter =
        struct(Tai.Venues.Adapter, %{
          id: :mock_boot,
          adapter: Tai.VenueAdapters.Mock,
          products: "*",
          accounts: %{main: %{}},
          timeout: @timeout
        })

      assert {:error, result} = Tai.Venues.Boot.run(adapter)
      assert {result_adapter, reasons} = result
      assert result_adapter == adapter
      assert reasons == [asset_balances: :mock_response_not_found]
    end
  end

  describe ".run fees hydrate error" do
    setup [:mock_products, :mock_asset_balances]

    test "returns an error" do
      adapter =
        struct(Tai.Venues.Adapter, %{
          id: :mock_boot,
          adapter: Tai.VenueAdapters.Mock,
          products: "*",
          accounts: %{main: %{}},
          timeout: @timeout
        })

      assert {:error, result} = Tai.Venues.Boot.run(adapter)
      assert {result_adapter, reasons} = result
      assert result_adapter == adapter
      assert reasons == [fees: :mock_response_not_found]
    end
  end

  def mock_products(_) do
    Tai.TestSupport.Mocks.Responses.Products.for_venue(
      @venue_id,
      [
        %{symbol: :btc_usdt},
        %{symbol: :eth_usdt},
        %{symbol: :ltc_usdt}
      ]
    )

    :ok
  end

  def mock_maker_taker_fees(_) do
    Tai.TestSupport.Mocks.Responses.MakerTakerFees.for_venue_and_account(
      @venue_id,
      @account_id,
      {Decimal.new("0.001"), Decimal.new("0.001")}
    )
  end

  def mock_asset_balances(_) do
    Tai.TestSupport.Mocks.Responses.AssetBalances.for_venue_and_account(
      @venue_id,
      @account_id,
      [
        %{asset: :btc, free: Decimal.new("0.1"), locked: Decimal.new("0.2")},
        %{asset: :eth, free: Decimal.new("0.3"), locked: Decimal.new("0.4")},
        %{asset: :ltc, free: Decimal.new("0.5"), locked: Decimal.new("0.6")},
        %{asset: :usdt, free: Decimal.new(0), locked: Decimal.new(0)}
      ]
    )

    :ok
  end
end
