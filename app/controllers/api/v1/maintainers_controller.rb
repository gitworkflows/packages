class Api::V1::MaintainersController < Api::V1::ApplicationController
  def index
    @registry = Registry.find_by_name!(params[:registry_id])
    scope = @registry.maintainers
    scope = scope.created_after(params[:created_after]) if params[:created_after].present?
    scope = scope.updated_after(params[:updated_after]) if params[:updated_after].present?

    if params[:sort].present? || params[:order].present?
      sort = params[:sort] || 'updated_at'
      order = params[:order] || 'desc'
      sort_options = sort.split(',').zip(order.split(',')).to_h
      scope = scope.order(sort_options)
    else
      scope = scope.order('updated_at DESC')
    end

    @pagy, @maintainers = pagy_countless(scope)
    fresh_when @maintainers, public: true
  end

  def show
    @registry = Registry.find_by_name!(params[:registry_id])
    @maintainer = @registry.maintainers.find_by_login(params[:id]) || @registry.maintainers.find_by_uuid!(params[:id])
    fresh_when @maintainer, public: true
  end

  def packages
    @registry = Registry.find_by_name!(params[:registry_id])
    @maintainer = @registry.maintainers.find_by_login(params[:id]) || @registry.maintainers.find_by_uuid!(params[:id])
    @pagy, @packages = pagy_countless(@maintainer.packages.includes(:registry,{maintainers: :registry}))
    fresh_when @packages, public: true
  end
end