class Cms::Admin::Data::FilesController < Cms::Controller::Admin::Base
  include Sys::Controller::Scaffold::Base
  include Sys::Controller::Scaffold::Publication

  def pre_dispatch
    return error_auth unless Core.user.has_auth?(:designer)

    return redirect_to(url_for(:action => "index", :parent => '0')) if params[:reset] || (params['s_node_id'] == '' && params[:s_keyword] == '' && params[:s_target] == '')
    
    if params[:parent] && params[:parent] != '0'
      @parent = Cms::DataFileNode.find(params[:parent])
    else
      @parent = Cms::DataFileNode.new
      @parent.id = 0
    end
  end

  def index
    if params['s_node_id']
      parent_id = params['s_node_id'] == '' ? 0 : params['s_node_id']
      return redirect_to(url_for(:action => "index", :parent => parent_id, :s_keyword => params[:s_keyword], :s_target => params[:s_target], :s_sort => params[:s_sort]))
    end

    @nodes = Cms::DataFileNode.where(concept_id: Core.concept(:id)).order(:name)

    files = Cms::DataFile.arel_table

    rel = Cms::DataFile.order(params[:s_sort] == 'updated_at' ? 'updated_at DESC, id' : 'name, id')
    rel = rel.where(files[:name].matches("%#{params[:s_keyword]}%")) if params[:s_keyword].present?
    rel = rel.where(node_id: @parent.id) unless @parent.id.zero?
    rel = unless Core.user.has_auth?(:manager) || params[:s_target] == 'current'
            rel.readable
          else
            rel = rel.where(concept_id: Core.concept.id) unless params[:s_target] == 'all'
            rel.where(site_id: Core.site.try(:id))
          end

    @items = rel.paginate(page: params[:page], per_page: params[:limit])
    _index @items
  end

  def show
    @item = Cms::DataFile.readable.find_by(id: params[:id])
    return error_auth unless @item.readable?
    _show @item
  end

  def new
    @item = Cms::DataFile.new({
      :concept_id => Core.concept(:id),
      :state      => 'public'
    })
  end

  def create
    @item = Cms::DataFile.new(data_file_params)
    @item.site_id = Core.site.id
    @item.state   = 'public'
    _create @item do
      @item.publish if @item.state == 'public'
    end
  end

  def update
    @item = Cms::DataFile.find(params[:id])
    @item.attributes = data_file_params
    @item.node_id    = nil if @item.concept_id_changed?
    @item.skip_upload
    _update @item
  end

  def destroy
    @item = Cms::DataFile.find(params[:id])
    _destroy @item
  end

  def download
    item = Cms::DataFile.new.readable
    item.and :id, params[:id]
    return error_auth unless @file = item.find(:first)
    
    send_file @file.upload_path, :type => @file.mime_type, :filename => @file.name, :disposition => 'inline'
  end

  private

  def data_file_params
    params.require(:item).permit(:concept_id, :node_id, :file, :name, :title)
  end
end
