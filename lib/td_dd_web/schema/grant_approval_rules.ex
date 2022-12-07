defmodule TdDdWeb.Schema.GrantApprovalRules do
  @moduledoc """
  Absinthe schema definitions for Grant Approval Rules
  """
  use Absinthe.Schema.Notation

  alias TdDdWeb.Resolvers

  object :grant_approval_rules_queries do
    @desc "Get list of grant approval rules"
    field :grant_approval_rules, list_of(:approval_rule) do
      resolve(&Resolvers.GrantApprovalRules.grant_approval_rules/3)
    end

    @desc "Get grant approval rule"
    field :grant_approval_rule, :approval_rule do
      arg(:id, non_null(:id))
      resolve(&Resolvers.GrantApprovalRules.grant_approval_rule/3)
    end
  end

  object :grant_approval_rules_mutations do
    @desc "Create new grant approval rule"
    field :create_grant_approval_rule, :approval_rule do
      arg(:approval_rule, non_null(:create_grant_approval_rule_input))
      resolve(&Resolvers.GrantApprovalRules.create_grant_approval_rule/3)
      middleware(Crudry.Middlewares.TranslateErrors)
    end

    @desc "Update grant approval rule"
    field :update_grant_approval_rule, :approval_rule do
      arg(:approval_rule, non_null(:update_grant_approval_rule_input))
      resolve(&Resolvers.GrantApprovalRules.update_grant_approval_rule/3)
      middleware(Crudry.Middlewares.TranslateErrors)
    end

    @desc "Delete a grant approval rule"
    field :delete_grant_approval_rule, :approval_rule do
      arg(:id, non_null(:id))
      resolve(&Resolvers.GrantApprovalRules.delete_grant_approval_rule/3)
      middleware(Crudry.Middlewares.TranslateErrors)
    end
  end

  input_object :create_grant_approval_rule_input do
    field :name, non_null(:string)
    field :action, non_null(:string)
    field :role, non_null(:string)
    field :domain_ids, list_of(:id)
    field :conditions, list_of(:condition_input)
    field :comment, :string
  end

  input_object :condition_input do
    field :field, non_null(:string)
    field :operator, non_null(:string)
    field :values, non_null(list_of(non_null(:string)))
  end

  input_object :update_grant_approval_rule_input do
    field :id, non_null(:id)
    field :name, :string
    field :action, :string
    field :role, :string
    field :domain_ids, list_of(:id)
    field :conditions, list_of(:condition_input)
    field :comment, :string
  end

  object :approval_rule do
    field :id, non_null(:id)
    field :name, non_null(:string)
    field :user_id, non_null(:id)
    field :action, non_null(:string)
    field :role, non_null(:string)
    field :domain_ids, list_of(:id)
    field :domains, list_of(:domain), resolve: &Resolvers.Domains.domains/3
    field :conditions, list_of(:condition)
    field :comment, :string
    field :inserted_at, :datetime
    field :updated_at, :datetime
  end

  object :condition do
    field :field, non_null(:string)
    field :operator, non_null(:string)
    field :values, list_of(:string)
  end
end
