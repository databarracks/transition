require 'view/mappings/canonical_filter'

class MappingsController < ApplicationController
  include PaperTrail::Rails::Controller

  tracks_mappings_progress except: [:find_global]

  before_filter :check_global_redirect_or_archive, except: [:find_global]
  checks_user_can_edit except: [:index, :find, :find_global]

  def index
    @filter = View::Mappings::Filter.new(@site, params)
    respond_to do |format|
      format.html do
        @mappings = @filter.mappings
        render :index
      end
      format.csv do
        if current_user.admin?
          @mappings = @filter.unpaginated_mappings
          data = MappingsCSVPresenter.new(@mappings).to_csv
          timestamp = I18n.l(Time.zone.now, :format => :govuk_date)
          filename = "#{@site.default_host.hostname} mappings at #{timestamp}.csv"
          send_data data, filename: filename
        else
          safely_redirect_to_start_point(notice: 'Only admin users can access the CSV export')
        end
      end
    end
  end

  def edit
    @mapping = Mapping.find(params[:id])
  end

  def update
    @mapping = @site.mappings.find(params[:id])

    # Tags must be assigned to separately
    @mapping.tag_list = params[:mapping].delete(:tag_list)
    @mapping.attributes = mapping_params[:mapping]

    if @mapping.save
      flash[:success] = 'Mapping saved'
      flash[:saved_mapping_ids] = [@mapping.id]
      flash[:saved_operation] = "update-single"
      safely_redirect_to_start_point
    else
      render action: 'edit'
    end
  end

  def edit_multiple
    redirect_to bulk_edit.return_path, notice: bulk_edit.params_errors and return if bulk_edit.params_invalid?

    if request.xhr?
      render 'edit_multiple_modal', layout: nil
    end
  end

  def update_multiple
    redirect_to bulk_edit.return_path, notice: bulk_edit.params_errors and return if bulk_edit.params_invalid?

    if bulk_edit.would_fail?
      if bulk_edit.would_fail_on_new_url?
        render action: 'edit_multiple' and return
      else
        flash[:danger] = 'Validation failed'
        return redirect_to bulk_edit.return_path
      end
    end

    bulk_edit.update!

    if bulk_edit.failures?
      @mappings = bulk_edit.failures
      flash[:notice] = 'The following mappings could not be updated'
      render action: 'edit_multiple'
    else
      flash[:success] = bulk_edit.success_message
      flash[:saved_mapping_ids] = bulk_edit.mappings.map {|m| m.id}
      flash[:saved_operation] = bulk_edit.analytics_event_type
      redirect_to bulk_edit.return_path
    end
  end

  def find_global
    # This allows finding a mapping without knowing the site first.
    render_error(400) and return unless params[:url].present?

    if !Transition::PathOrURL.starts_with_http_scheme?(params[:url])
      url = 'http://' + params[:url] # Add a dummy scheme
    else
      url = params[:url]
    end

    begin
      url = Addressable::URI.parse(url)
    rescue Addressable::URI::InvalidURIError
      render_error(400) and return
    end

    url.host = Host.canonical_hostname(url.host)
    site = Host.where(hostname: url.host).first.try(:site)
    unless site
      render_error(404,
          header: 'Unknown site',
          body:  "#{url.host} isn't configured in Transition yet. To add this site to Transition, please contact your Proposition Manager.")
      return
    end

    # Only redirect to the mapping if the original URL had a path,
    # otherwise this errors because / is not editable.
    if url.request_uri =~ /^\/.+/
      redirect_to site_mapping_find_url(site, path: url.request_uri)
    else
      redirect_to site_url(site)
    end
  end

  def find
    path = @site.canonical_path(params[:path])

    if path.empty?
      notice = t('mappings.not_possible_to_edit_homepage_mapping')
      return redirect_to back_or_mappings_index, notice: notice
    end

    mapping = @site.mappings.find_by_path(path)
    if mapping.present?
      redirect_to edit_site_mapping_path(@site, mapping, return_path: params[:return_path])
    else
      redirect_to new_site_bulk_add_batch_path(@site, paths: path, return_path: params[:return_path])
    end
  end

private
  def mapping_params
    params.permit(mapping: [
                             :type,
                             :path,
                             :new_url,
                             :tag_list,
                             :suggested_url,
                             :archive_url
                           ])
  end

  def bulk_edit
    @bulk_edit ||= bulk_editor_class.new(@site, params, site_mappings_path(@site))
  end

  def bulk_editor_class
    params[:operation] == 'tag' ? View::Mappings::BulkTagger : View::Mappings::BulkEditor
  end

  def back_or_mappings_index
    referer = request.env['HTTP_REFERER']
    if referer && Addressable::URI.parse(referer).host == request.host
      referer
    else
      site_mappings_path(@site)
    end
  end

  def check_global_redirect_or_archive
    if @site.global_type.present?
      if @site.global_redirect?
        message = "This site has been entirely redirected."
      elsif @site.global_archive?
        message = "This site has been entirely archived."
      end
      redirect_to site_path(@site), alert: "#{message} You can't edit its mappings."
    end
  end

  def safely_redirect_to_start_point(redirect_to_options={})
    if Transition::OffSiteRedirectChecker.on_site?(params[:return_path])
      redirect_to params[:return_path], redirect_to_options
    else
      redirect_to site_mappings_path(@site), redirect_to_options
    end
  end
end
