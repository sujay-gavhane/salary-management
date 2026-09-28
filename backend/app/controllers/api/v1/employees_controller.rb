module Api
  module V1
    class EmployeesController < ApplicationController
      PERMITTED_ATTRIBUTES = %i[full_name email job_title department country salary employment_type hire_date].freeze

      before_action :set_employee, only: %i[show update destroy]

      def show
        authorize @employee
        render json: { data: EmployeeSerializer.new(@employee).as_json }
      end

      def create
        authorize Employee
        employee = Employee.create!(employee_params)
        render json: { data: EmployeeSerializer.new(employee).as_json }, status: :created
      end

      def update
        authorize @employee
        @employee.update!(employee_params)
        render json: { data: EmployeeSerializer.new(@employee).as_json }
      end

      def destroy
        authorize @employee
        @employee.destroy!
        head :no_content
      end

      private

      def set_employee
        @employee = policy_scope(Employee).find(params[:id])
      end

      def employee_params
        params.expect(employee: PERMITTED_ATTRIBUTES)
      end
    end
  end
end
