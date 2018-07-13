defmodule Tai.Exchanges.AccountSupervisor do
  @moduledoc """
  Supervisor that starts the account adapter and the balances supervisor
  """

  use Supervisor

  def start_link(account_id) do
    Supervisor.start_link(
      __MODULE__,
      account_id,
      name: :"#{__MODULE__}_#{account_id}"
    )
  end

  def init(account_id) do
    [
      {Tai.Exchanges.Config.account_adapter(account_id), account_id},
      {Tai.Exchanges.BalanceSupervisor, account_id}
    ]
    |> Supervisor.init(strategy: :one_for_one)
  end
end
