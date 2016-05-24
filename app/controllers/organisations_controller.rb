class OrganisationsController < ApplicationController
  before_filter :set_organisation, only: [:show, :update, :edit]

  def index
    @organisations = Organisation.order(:title)
    @site_count = Site.count
  end

  def show
    sites = @organisation.sites.includes(:hosts)
    extra_sites = @organisation.extra_sites.includes(:hosts)
    @sites = sites.concat(extra_sites).sort_by!(&:abbr)
  end

  def new
    @organisation = Organisation.new
  end

  def create
    @organisation = Organisation.create(organisation_params.merge(content_id: SecureRandom.uuid))
    if @organisation.valid?
      redirect_to action: :show, id: @organisation.whitehall_slug
    else
      render :new
    end
  end

  def edit
  end

  def update
    @organisation.update!(organisation_params)
    if @organisation.valid?
      redirect_to action: :show
    else
      render :edit
    end
  end

  private def set_organisation
    @organisation = Organisation.find_by_whitehall_slug!(params[:id])
  end

  private def organisation_params
    params[:organisation].permit \
      :title,
      :homepage,
      :whitehall_slug,
      :whitehall_type,
      :abbreviation
  end
end
