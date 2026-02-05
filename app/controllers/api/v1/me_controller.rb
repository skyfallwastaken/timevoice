# frozen_string_literal: true

module Api
  module V1
    class MeController < BaseController
      def show
        render json: current_user.as_json(only: [ :id, :email, :name ])
      end
    end
  end
end
