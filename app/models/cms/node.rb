# encoding: utf-8
class Cms::Node < ActiveRecord::Base
  include Sys::Model::Base
  include Cms::Model::Base::Page
  include Cms::Model::Base::Page::Publisher
  include Cms::Model::Base::Page::TalkTask
  include Cms::Model::Base::Node
  include Sys::Model::Tree
  include Sys::Model::Rel::Unid
  include Sys::Model::Rel::UnidRelation
  include Sys::Model::Rel::Creator
  include Cms::Model::Rel::Site
  include Cms::Model::Rel::Concept
  include Cms::Model::Rel::Content
  include Cms::Model::Auth::Concept

  include StateText
  
  SITEMAP_STATE_OPTIONS = [['表示', 'visible'], ['非表示', 'hidden']]

  belongs_to :parent,   :foreign_key => :parent_id,  :class_name => 'Cms::Node'
  belongs_to :layout,   :foreign_key => :layout_id,  :class_name => 'Cms::Layout'

  has_many :children, -> { order('sitemap_sort_no IS NULL, sitemap_sort_no, name') },
    :foreign_key => :parent_id, :class_name => 'Cms::Node', :dependent => :destroy
  has_many :children_in_route, -> { order('sitemap_sort_no IS NULL, sitemap_sort_no, name') },
    :foreign_key => :route_id,  :class_name => 'Cms::Node', :dependent => :destroy

  validates_presence_of :parent_id, :state, :model, :name, :title
  validates_uniqueness_of :name, :scope => [:site_id, :parent_id],
    :if => %Q(!replace_page?)
  validates_format_of :name, :with=> /\A[0-9A-Za-z@\.\-_\+\s]+\z/, :message=> :not_a_filename,
    :if => %Q(parent_id != 0)

  after_initialize :set_defaults
  after_destroy :remove_file

  scope :public, -> { where(state: 'public') }

  def validate
    errors.add :parent_id, :invalid if id != nil && id == parent_id
    errors.add :route_id, :invalid if id != nil && id == route_id
  end
  
  def states
    [['公開保存','public'],['非公開保存','closed']]
  end
  
  def self.find_by_uri(path, site_id)
    return nil if path.to_s == ''
    
    cond = {:site_id => site_id, :parent_id => 0, :name => '/'}
    unless item = self.find(:first, :conditions => cond, :order => :id)
      return nil
    end
    return item if path == '/'
    
    path.split('/').each do |p|
      next if p == ''
      cond = {:site_id => site_id, :parent_id => item.id, :name => p}
      unless item = self.find(:first, :conditions => cond, :order => :id)
        return nil
      end
    end
    return item
  end
  
  def public_path
    "#{site.public_path}#{public_uri}".gsub(/\?.*/, '')
  end

  def public_mobile_path
    "#{site.public_path}/_mobile#{public_uri}".gsub(/\?.*/, '')
  end

  def public_smart_phone_path
    "#{site.public_path}/_smartphone#{public_uri}".gsub(/\?.*/, '')
  end

  def public_uri=(uri)
    @public_uri = uri
  end
  
  def public_uri
    return @public_uri if @public_uri
    uri = site.uri
    parents_tree.each{|n| uri += "#{n.name}/" if n.name != '/' }
    uri = uri.gsub(/\/$/, '') if directory == 0
    @public_uri = uri
  end
  
  def public_full_uri
    return @public_full_uri if @public_full_uri
    uri = site.full_uri
    parents_tree.each{|n| uri += "#{n.name}/" if n.name != '/' }
    uri = uri.gsub(/\/$/, '') if directory == 0
    @public_full_uri = uri
  end
  
  def inherited_concept(key = nil)
    if !@_inherited_concept
      concept_id = self.concept_id
      parents_tree.each do |r|
        concept_id = r.concept_id if r.concept_id
      end unless concept_id
      return nil unless concept_id
      return nil unless @_inherited_concept = Cms::Concept.find(:first, :conditions => {:id => concept_id})
    end
    key.nil? ? @_inherited_concept : @_inherited_concept.send(key)
  end
  
  def inherited_layout
    layout_id = layout_id
    parents_tree.each do |r|
      layout_id = r.layout_id if r.layout_id
    end unless layout_id
    Cms::Layout.where(id: layout_id).first
  end
  
  def all_nodes_with_level
    search = lambda do |current, level|
      _nodes = {:level => level, :item => current, :children => nil}
      return _nodes if level >= 10
      return _nodes if current.children.size == 0
      
      _tmp = []
      current.children.each do |child|
        next unless _c = search.call(child, level + 1)
        _tmp << _c
      end
      _nodes[:children] = _tmp
      return _nodes
    end
    
    search.call(self, 0)
  end
  
  def all_nodes_collection(options = {})
    collection = lambda do |current, level|
      title = ''
      if level > 0
        (level - 0).times {|i| title += options[:indent] || '  '}
        title += options[:child] || ' ' if level > 0
      end
      title += current[:item].title
      list = [[title, current[:item].id]]
      return list unless current[:children]
      
      current[:children].each do |child|
        list += collection.call(child, level + 1)
      end
      return list
    end
    
    collection.call(all_nodes_with_level, 0)
  end
  
  def css_id
    ''
  end
  
  def css_class
    return 'content content' + self.controller.singularize.camelize
  end
  
  def make_candidates(args1, args2)
    choiced = []
    choices = []
    down    = lambda do |p, i|
      next if choiced[p.id] != nil
      choiced[p.id] = true
      
      choices << [('　　' * i) + p.title, p.id]
      self.class.find(:all, eval("{#{args2}}")).each do |c|
        down.call(c, i + 1)
      end
    end
    
    self.class.find(:all, eval("{#{args1}}")).each {|item| down.call(item, 0) }
    return choices
  end
  
  def candidate_parents
    args1  = %Q( :conditions => ["id = ?", Core.site.root_node], )
    args1 += %Q( :order => :name)
    args2  = %Q( :conditions => ["id != ? AND parent_id = ? AND directory = 1", id, p.id], )
    args2  = %Q( :conditions => ["parent_id = ? AND directory = 1", p.id], ) if new_record?
    args2 += %Q( :order => :name)
    make_candidates(args1, args2)
  end
  
  def candidate_routes
    args1  = %Q( :conditions => ["id = ?", Core.site.root_node], )
    args1 += %Q( :order => :name)
    args2  = %Q( :conditions => ["id != ? AND parent_id = ? AND directory = 1", id, p.id], )
    args2  = %Q( :conditions => ["parent_id = ? AND directory = 1", p.id], ) if new_record?
    args2 += %Q( :order => :name)
    make_candidates(args1, args2)
  end
  
  def locale(name)
    model = self.class.to_s.underscore
    label = ''
    if model != 'cms/node'
      label = I18n.t name, :scope => [:activerecord, :attributes, model]
      return label if label !~ /^translation missing:/
    end
    label = I18n.t name, :scope => [:activerecord, :attributes, 'cms/node']
    return label =~ /^translation missing:/ ? name.to_s.humanize : label
  end
  
  def search(params)
    params.each do |n, v|
      next if v.to_s == ''

      case n
      when 's_state'
        self.and :state, v
      when 's_title'
        self.and_keywords v, :title
      when 's_body'
        self.and_keywords v, :body
      when 's_directory'
        self.and :directory, v
      when 's_keyword'
        self.and_keywords v, :title, :body
      end
    end if params.size != 0

    return self
  end

  def sitemap_visible?
    self.sitemap_state == 'visible'
  end

  def public_children
    children.public
  end

  def public_children_in_route
    children_in_route.public
  end
  
  def set_inquiry_group
    inquiries.each_with_index do |inquiry, i|
      next if i != 0
      inquiry.group_id = in_creator["group_id"]
    end
  end

  def pdf_in_body?(html)
    extract_links(html, false).any?{|l| l[:url] =~ /\.pdf$/i }
  end

  def top_page?
    parent.try(:parent_id) == 0 && name == 'index.html'
  end

protected
  def remove_file
    close_page# rescue nil
    return true
  end
  
  class Directory < Cms::Node
    def close_page(options = {})
      return true
    end
  end
  
  class Sitemap < Cms::Node
  end

  class Page < Cms::Node
    include Sys::Model::Rel::Recognition
    include Cms::Model::Rel::ManyInquiry
#    include Cms::Model::Rel::Inquiry
    include Sys::Model::Rel::Task
    
#    validate :validate_inquiry,
#      :if => %Q(state == 'public')
    validate :validate_recognizers,
      :if => %Q(state == "recognize")
    
    def unid_model_name
      'Cms::Node'
    end
    
    def states
      s = [['下書き保存','draft'],['承認待ち','recognize']]
      s << ['公開保存','public'] if Core.user.has_auth?(:manager)
      s
    end
    
    def publish(content)
      @save_mode = :publish
      self.state = 'public'
      self.published_at ||= Core.now
      return false unless save(:validate => false)
      
      if rep = replaced_page
        rep.destroy if rep.directory == 0
      end
      
      publish_page(content, :path => public_path, :uri => public_uri)
    end

    def rebuild(content, options={})
      if options[:dependent] == :smart_phone
        return false unless self.site.publish_for_smart_phone?
        return false unless self.site.spp_all? || (self.site.spp_only_top? && top_page?)
      end

      return false unless self.state == 'public'
      @save_mode = :publish

      if rep = replaced_page
        rep.destroy if rep.directory == 0
      end

      options[:path] ||= public_path
      options[:uri] ||= public_uri

      publish_page(content, options)
    end
    
    def close
      @save_mode = :close
      self.state = 'closed' if self.state == 'public'
      #self.published_at = nil
      return false unless save(:validate => false)
      close_page
      return true
    end
    
    def duplicate(rel_type = nil)
      item = self.class.new(self.attributes)
      item.id            = nil
      item.unid          = nil
      item.created_at    = nil
      item.updated_at    = nil
      item.recognized_at = nil
      #item.published_at  = nil
      item.state         = 'draft'
      
      if rel_type == nil
        item.name          = nil
        item.title         = item.title.gsub(/^(【複製】)*/, "【複製】")
      end
      
      item.in_recognizer_ids  = recognition.recognizer_ids if recognition
      
#      if inquiry != nil && inquiry.group_id == Core.user.group_id
#        item.in_inquiry = inquiry.attributes
#      else
#        item.in_inquiry = {:group_id => Core.user.group_id}
#      end

      inquiries.each_with_index do |inquiry, i|
        attrs = inquiry.attributes
        attrs[:id] = nil
        attrs[:group_id] = Core.user.group_id if i.zero?
        item.inquiries.build(attrs)
      end

      return false unless item.save(:validate => false)
      
      if rel_type == :replace
        rel = Sys::UnidRelation.new
        rel.unid     = item.unid
        rel.rel_unid = self.unid
        rel.rel_type = 'replace'
        rel.save
      end
      
      return item
    end
  end

  private

  def set_defaults
    self.sitemap_state ||= SITEMAP_STATE_OPTIONS.first.last if self.has_attribute?(:sitemap_state)
    self.directory = (model_type == :directory) if self.has_attribute?(:directory) && directory.nil?
  end

  def extract_links(html, all)
    links = Nokogiri::HTML.fragment(html).css('a[@href]').map {|a| {body: a.text, url: a.attribute('href').value} }
    return links if all
    links.select do |link|
      uri = URI.parse(link[:url]) rescue nil
      next false if uri.blank?
      next true unless uri.absolute?
      [URI::HTTP, URI::HTTPS, URI::FTP].include?(uri.class)
    end
  rescue => evar
    warn_log evar.message
    return []
  end

end
