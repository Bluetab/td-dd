defmodule TdDq.Canada.ImplementationAbilitiesTest do
  use TdDd.DataCase

  import TdDq.Canada.ImplementationAbilities, only: [can?: 3]

  @actions [:edit, :delete, :publish, :reject, :submit, :move, :clone, :execute]

  @valid_actions %{
    draft: [:edit, :submit, :delete, :move, :clone, :publish],
    pending_approval: [:publish, :reject, :delete, :clone],
    published: [:delete, :move, :clone, :execute, :edit],
    rejected: [:edit, :move, :delete, :clone],
    deprecated: [:clone],
    versioned: [:clone]
  }

  setup do
    [admin: build(:claims, role: "admin")]
  end

  for {status, valid_actions} <- @valid_actions do
    describe "status #{status}:" do
      for action <- valid_actions do
        @tag status: status, action: action
        test "admin should be able to #{action}", %{admin: claims, status: status, action: action} do
          implementation = insert(:implementation, status: status)
          assert can?(claims, action, implementation), "admin cannot #{action} (#{status})"
        end
      end

      for action <- Enum.reject(@actions, &Enum.member?(valid_actions, &1)) do
        @tag status: status, action: action
        test "admin should not be able to #{action}", %{
          admin: claims,
          status: status,
          action: action
        } do
          implementation = insert(:implementation, status: status)
          refute can?(claims, action, implementation), "admin can #{action} (#{status})"
        end
      end
    end
  end
end
