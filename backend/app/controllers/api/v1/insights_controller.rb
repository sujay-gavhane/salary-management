module Api
  module V1
    class InsightsController < ApplicationController
      before_action { authorize :insights, :show? }

      def countries
        render json: { data: InsightsSerializer.new(insights.by_country).as_json, rates_as_of: }
      end

      def job_titles
        country = params[:country].to_s
        rows = insights.by_job_title(country)

        render json: {
          data: InsightsSerializer.new(rows).as_json,
          country:,
          currency: Country.currency_for(country),
          rates_as_of:
        }
      end

      private

      def insights
        @insights ||= SalaryInsights.new(policy_scope(Employee))
      end

      def rates_as_of = insights.rates_as_of&.iso8601
    end
  end
end
