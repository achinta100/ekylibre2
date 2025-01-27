# frozen_string_literal: true

module Labellable
  extend ActiveSupport::Concern

  included do
    belongs_to :label
    delegate :color, :name, to: :label
  end
end
