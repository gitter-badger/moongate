defmodule Test.Game do
  import Moongate

  stages %{
    login_screen: Test.Stage.LoginScreen,
    test_stage: Test.Stage.TestStage
  }
  def connected(event) do
    arrive event, :login_screen
  end
end
