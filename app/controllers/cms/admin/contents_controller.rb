# encoding: utf-8
class Cms::Admin::ContentsController < Cms::Controller::Admin::Base
  include Sys::Controller::Scaffold::Base
  
  def pre_dispatch
    #return error_auth unless Core.user.has_auth?(:designer)
  end
  
  def index
    return show_htaccess if params.key?(:htaccess)

    @items = Cms::Content.readable.order('name, id')
                         .paginate(page: params[:page], per_page: params[:limit])
    _index @items
  end
  
  def show_htaccess #dev
    conf = []
    
    cond = {:model => "Article::Doc"}
    Article::Content::Doc.find(:all, :conditions => cond, :order => :id).each do |c|
      next if c.doc_node == nil
      
      line  = "RewriteRule"
      line += " ^#{c.doc_node.public_uri}" + '((\d{4})(\d\d)(\d\d)(\d\d)(\d\d)(\d).*)'
      line += " #{c.public_path.gsub(/.*(\/_contents\/)/, '\\1')}/docs/$2/$3/$4/$5/$6/$1 [L]"
      line += " #contents/#{c.id}"
      conf << line
    end
    
    html  = %Q(<div style="font-size: 12px; font-family: 'MS Gothic'; line-height: 1.2;">)
    html += %Q(#{conf.join("<br />\n")}</div>)
    render :text => html
  end
  
  def show
    @item = Cms::Content.new.find(params[:id])
    return error_auth unless @item.readable?
    
    _show @item
  end

  def new
    @item = Cms::Content.new({
      :concept_id => Core.concept(:id),
      :state      => 'public',
    })
  end

  def create
    begin
      @item = params[:item][:model].split('::').join('::Content::').constantize.new(content_params)
    rescue
      @item = Cms::Content.new(content_params)
    end
    @item.state   = 'public'
    @item.site_id = Core.site.id
    _create @item
  end

  def update
    @item = Cms::Content.new.find(params[:id])
    @item.attributes = content_params
    _update @item
  end
  
  def destroy
    @item = Cms::Content.new.find(params[:id])
    _destroy @item
  end

  private

  def content_params
    params.require(:item).permit(:code, :concept_id, :in_creator, :model, :name, :note)
  end
end
